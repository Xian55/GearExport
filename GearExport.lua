-- GearExport: Export equipped gear as JSON for TurtleAtlasLoot Gear Planner
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

local function GetEquippedGearJSON(setName)
    setName = setName or UnitName("player") .. " Gear"

    local slots = {}
    for slotId, slotName in pairs(SLOT_MAP) do
        local link = GetInventoryItemLink("player", slotId)
        if link then
            local _, _, idStr = string.find(link, "item:(%d+)")
            if idStr then
                local itemId = tonumber(idStr)
                table.insert(slots, {name = slotName, itemId = itemId})
            end
        end
    end

    -- Sort slots for consistent output
    table.sort(slots, function(a, b) return a.name < b.name end)

    -- Build JSON string manually (no json lib in vanilla WoW)
    local lines = {}
    table.insert(lines, "[")
    table.insert(lines, "  {")
    table.insert(lines, '    "name": "' .. setName .. '",')
    table.insert(lines, '    "slots": {')

    for i, slot in ipairs(slots) do
        local comma = ","
        if i == table.getn(slots) then comma = "" end
        table.insert(lines, '      "' .. slot.name .. '": {')
        table.insert(lines, '        "itemId": ' .. slot.itemId .. ',')
        table.insert(lines, '        "obtained": true')
        table.insert(lines, "      }" .. comma)
    end

    table.insert(lines, "    }")
    table.insert(lines, "  }")
    table.insert(lines, "]")

    return table.concat(lines, "\n")
end

-- EditBox frame for copy-paste (created on demand)
local copyFrame

local function CreateCopyFrame()
    if copyFrame then return end

    copyFrame = CreateFrame("Frame", "GearExportCopyFrame", UIParent)
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

local function ShowExport(text)
    CreateCopyFrame()
    copyFrame.editBox:SetText(text)
    copyFrame:Show()
    copyFrame.editBox:HighlightText()
    copyFrame.editBox:SetFocus()
end

function GearExport_OnLoad()
    this:RegisterEvent("VARIABLES_LOADED")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00GearExport|r loaded. Type |cffffff00/gearexport|r to export your gear.")
end

function GearExport_OnEvent(event)
    if event == "VARIABLES_LOADED" then
        SlashCmdList["GEAREXPORT"] = function(msg)
            local setName = msg
            if not setName or setName == "" then
                setName = UnitName("player") .. " Gear"
            end
            local json = GetEquippedGearJSON(setName)
            ShowExport(json)
        end
        SLASH_GEAREXPORT1 = "/gearexport"
        SLASH_GEAREXPORT2 = "/ge"
    end
end
