-- GearExport: Export equipped gear as JSON for TurtleAtlasLoot Gear Planner
--
-- One source, three clients: Vanilla 1.12 (Lua 5.0), TBC 2.4.3 (Lua 5.1) and
-- Burning Crusade Classic 2.5.x. Lua 5.0 has no "#" operator and no
-- string.gmatch, while 2.5.x dropped table.getn and passes (self, ...) to
-- widget handlers instead of exposing "this"/"arg1" as globals. Everything
-- below stays inside the subset all three share: string.find for parsing,
-- manual counters for lengths, and handler arguments that fall back to globals.

-- Slot mapping: WoW inventory slot ID -> Gear Planner slot name
local SLOT_MAP = {
    [1]  = "Head",
    [2]  = "Neck",
    [3]  = "Shoulder",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [11] = "Finger1",
    [12] = "Finger2",
    [13] = "Trinket1",
    [14] = "Trinket2",
    [15] = "Back",
    [16] = "MainHand",
    [17] = "OffHand",
    [18] = "Ranged",
}

-- 2.5.x frames only gain SetBackdrop when they inherit BackdropTemplate; on
-- 1.12 and 2.4.3 every frame has it and the template does not exist.
local BACKDROP_TEMPLATE
if BackdropTemplateMixin then BACKDROP_TEMPLATE = "BackdropTemplate" end

-- Splits the "item:..." payload of an item link into its raw fields.
-- Returns the field table and the field count, or nil when the link is not an
-- item link.
local function SplitItemFields(link)
    local _, _, payload = string.find(link, "|Hitem:([^|]+)|h")
    if not payload then
        _, _, payload = string.find(link, "item:([^|]*)")
    end
    if not payload then return nil end

    local fields, count = {}, 0
    payload = payload .. ":" -- sentinel so the final field is picked up too
    local pos = 1
    while true do
        local stop = string.find(payload, ":", pos, true)
        if not stop then break end
        count = count + 1
        fields[count] = string.sub(payload, pos, stop - 1)
        pos = stop + 1
    end
    return fields, count
end

-- The item payload layout differs per client:
--   1.12   itemId:enchant:suffix:unique                        -> 4 fields
--   2.4.3  itemId:enchant:gem1:gem2:gem3:gem4:suffix:unique    -> 8 fields
--   2.5.x  the 2.4.3 layout plus level/spec/bonus-id trailers  -> 14+ fields
-- itemId and enchant never move, and the gem block only exists on the socketed
-- layouts, so the field count alone tells the two apart -- no version check.
local SOCKETED_LAYOUT_MIN_FIELDS = 7

-- Returns itemId, enchantId, suffixId, gems, gemCount. enchantId, suffixId and
-- gems are nil when absent; gems holds only the filled sockets, in socket order.
local function ParseItemLink(link)
    local fields, count = SplitItemFields(link)
    if not fields then return nil end

    local itemId = tonumber(fields[1])
    if not itemId then return nil end

    local enchantId = tonumber(fields[2])
    if enchantId == 0 then enchantId = nil end

    local suffixId, gems, gemCount
    if count >= SOCKETED_LAYOUT_MIN_FIELDS then
        gemCount = 0
        gems = {}
        for i = 3, 6 do
            local gemId = tonumber(fields[i])
            if gemId and gemId ~= 0 then
                gemCount = gemCount + 1
                gems[gemCount] = gemId
            end
        end
        if gemCount == 0 then gems = nil end
        suffixId = tonumber(fields[7])
    else
        suffixId = tonumber(fields[3])
    end
    if suffixId == 0 then suffixId = nil end

    return itemId, enchantId, suffixId, gems, gemCount
end

local function EscapeJSON(text)
    text = string.gsub(text, "\\", "\\\\")
    text = string.gsub(text, '"', '\\"')
    return text
end

local function GetEquippedGearJSON(setName, unit)
    unit = unit or "player"
    setName = setName or (UnitName(unit) .. " Gear")

    local race = UnitRace(unit)
    local class = UnitClass(unit)
    local level = UnitLevel(unit)

    local slots, slotCount = {}, 0
    for slotId, slotName in pairs(SLOT_MAP) do
        local link = GetInventoryItemLink(unit, slotId)
        if link then
            local itemId, enchantId, suffixId, gems, gemCount = ParseItemLink(link)
            if itemId then
                slotCount = slotCount + 1
                slots[slotCount] = {
                    name = slotName,
                    itemId = itemId,
                    enchantId = enchantId,
                    suffixId = suffixId,
                    gems = gems,
                    gemCount = gemCount,
                }
            end
        end
    end

    -- Sort slots for consistent output
    table.sort(slots, function(a, b) return a.name < b.name end)

    -- Build JSON string manually (no json lib in vanilla WoW)
    local lines = {}
    table.insert(lines, "[")
    table.insert(lines, "  {")
    table.insert(lines, '    "name": "' .. EscapeJSON(setName) .. '",')
    table.insert(lines, '    "race": "' .. race .. '",')
    table.insert(lines, '    "class": "' .. class .. '",')
    table.insert(lines, '    "level": ' .. level .. ',')
    table.insert(lines, '    "slots": {')

    for i = 1, slotCount do
        local slot = slots[i]
        local comma = ","
        if i == slotCount then comma = "" end
        table.insert(lines, '      "' .. slot.name .. '": {')
        table.insert(lines, '        "itemId": ' .. slot.itemId .. ',')
        if slot.enchantId then
            table.insert(lines, '        "enchantId": ' .. slot.enchantId .. ',')
        end
        if slot.suffixId then
            table.insert(lines, '        "suffixId": ' .. slot.suffixId .. ',')
        end
        if slot.gems then
            local gemList = {}
            for g = 1, slot.gemCount do
                gemList[g] = slot.gems[g]
            end
            table.insert(lines, '        "gems": [' .. table.concat(gemList, ", ") .. '],')
        end
        table.insert(lines, '        "obtained": true')
        table.insert(lines, "      }" .. comma)
    end

    table.insert(lines, "    }")
    table.insert(lines, "  }")
    table.insert(lines, "]")

    return table.concat(lines, "\n"), slotCount
end

-- EditBox frame for copy-paste (created on demand)
local copyFrame

local function CreateCopyFrame()
    if copyFrame then return end

    copyFrame = CreateFrame("Frame", "GearExportCopyFrame", UIParent, BACKDROP_TEMPLATE)
    copyFrame:SetWidth(500)
    copyFrame:SetHeight(400)
    copyFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    copyFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    copyFrame:SetMovable(true)
    copyFrame:EnableMouse(true)
    copyFrame:RegisterForDrag("LeftButton")
    copyFrame:SetScript("OnDragStart", function() copyFrame:StartMoving() end)
    copyFrame:SetScript("OnDragStop", function() copyFrame:StopMovingOrSizing() end)
    copyFrame:SetFrameStrata("DIALOG")
    copyFrame:Hide()

    -- Title
    local title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("GearExport - Copy JSON")

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "GearExportScrollFrame", copyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 40)

    -- EditBox inside scroll
    local editBox = CreateFrame("EditBox", "GearExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(430)
    editBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() copyFrame:Hide() end)

    copyFrame.editBox = editBox
end

local LINE_HEIGHT = 14

local function CountLines(text)
    local lines, pos = 1, 1
    while true do
        local stop = string.find(text, "\n", pos, true)
        if not stop then break end
        lines = lines + 1
        pos = stop + 1
    end
    return lines
end

local function ShowExport(text)
    CreateCopyFrame()
    -- A scroll child needs an explicit height or 2.5.x clips it to one screen
    -- of text and the scrollbar never reaches the end of the JSON.
    copyFrame.editBox:SetHeight(CountLines(text) * LINE_HEIGHT)
    copyFrame.editBox:SetText(text)
    copyFrame:Show()
    copyFrame.editBox:HighlightText()
    copyFrame.editBox:SetFocus()
end

local function Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00GearExport:|r " .. text)
end

-- NotifyInspect is async: the server delivers the target's items a moment later
-- and slot by slot, so poll until the slot count stops growing rather than
-- reading once after a fixed delay (which can catch a half-filled set).
local INSPECT_TIMEOUT = 3.0
local INSPECT_POLL = 0.2

local inspectFrame = CreateFrame("Frame")
inspectFrame:Hide()
local inspectElapsed = 0
local inspectSincePoll = 0
local inspectLastCount = -1
local inspectSetName = nil

inspectFrame:SetScript("OnUpdate", function(self, elapsed)
    -- 1.12/2.4.3 call handlers with no arguments and expose the frame and the
    -- delta as the globals "this"/"arg1"; 2.5.x passes (self, elapsed).
    local delta = elapsed or arg1 or 0
    inspectElapsed = inspectElapsed + delta
    inspectSincePoll = inspectSincePoll + delta
    if inspectSincePoll < INSPECT_POLL then return end
    inspectSincePoll = 0

    if not UnitExists("target") or not UnitIsPlayer("target") then
        inspectFrame:Hide()
        Msg("target lost before inspect finished.")
        return
    end

    local json, count = GetEquippedGearJSON(inspectSetName, "target")
    if count > 0 and count == inspectLastCount then
        inspectFrame:Hide()
        ShowExport(json)
        return
    end
    inspectLastCount = count

    if inspectElapsed >= INSPECT_TIMEOUT then
        inspectFrame:Hide()
        if count > 0 then
            ShowExport(json)
        else
            Msg("no gear data for " .. (UnitName("target") or "target") ..
                " -- must be a same-faction player within inspect range (~10 yd).")
        end
    end
end)

-- Auto-detect: a valid (same-faction) player target is exported via inspect;
-- otherwise the player's own gear is exported. The optional msg sets the name.
local function ExportGear(msg)
    local setName = msg
    if not setName or setName == "" then setName = nil end

    if UnitExists("target") and UnitIsPlayer("target") then
        if not UnitIsFriend("player", "target") then
            Msg("cannot inspect a hostile target -- exporting your own gear.")
            ShowExport(GetEquippedGearJSON(setName, "player"))
            return
        end
        -- CanInspect only exists on 2.5.x; on 1.12/2.4.3 the range check below
        -- is left to the server, which simply returns no data.
        if CanInspect and not CanInspect("target") then
            Msg("cannot inspect " .. (UnitName("target") or "target") .. " -- exporting your own gear.")
            ShowExport(GetEquippedGearJSON(setName, "player"))
            return
        end
        NotifyInspect("target")
        inspectSetName = setName
        inspectElapsed = 0
        inspectSincePoll = 0
        inspectLastCount = -1
        inspectFrame:Show()
        Msg("inspecting " .. (UnitName("target") or "target") .. "...")
    else
        ShowExport(GetEquippedGearJSON(setName, "player"))
    end
end

function GearExport_OnLoad(frame)
    frame = frame or this
    frame:RegisterEvent("VARIABLES_LOADED")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00GearExport|r loaded. Type |cffffff00/gearexport|r to export your gear (or your target's).")
end

function GearExport_OnEvent(event)
    if event == "VARIABLES_LOADED" then
        SlashCmdList["GEAREXPORT"] = function(msg)
            ExportGear(msg)
        end
        SLASH_GEAREXPORT1 = "/gearexport"
        SLASH_GEAREXPORT2 = "/ge"
    end
end
