# GearExport

A WoW addon that exports your currently equipped gear as JSON, compatible with the [TurtleAtlasLoot Gear Planner](https://mrdobby92.github.io/TurtleAtlasLootWeb/gear-planner). Runs on Vanilla 1.12, TBC 2.4.3 and Burning Crusade Classic.

Browse and share exported characters at the [Tortoise DB Viewer](https://xian55.github.io/tortoise-db-viewer/?characters).

## Features

- Exports all 17 equipment slots (Head, Neck, Shoulder, Back, Chest, Wrist, Hands, Waist, Legs, Feet, Finger 1 & 2, Trinket 1 & 2, Main Hand, Off Hand, Ranged)
- Includes the character's race, class, level, applied item enchants, and any random suffix (e.g. "of the Bear")
- **Exports socketed gems** on TBC — the itemId of every gem slotted into an item is included
- Exports **your target's** gear too — select a friendly player and run the command to inspect and export their equipment
- Outputs JSON in the exact format the Gear Planner expects for import
- Provides a scrollable, copy-friendly text window in-game
- Supports custom set names

## Installation

1. Download the release zip that matches your client (see [Compatibility](#compatibility)), or clone this repository
2. Copy the `GearExport` folder into your `Interface/AddOns/` directory
3. Restart the game or type `/reload`

## Usage

| Command | Description |
|---|---|
| `/gearexport` | Export gear with default name (`<CharacterName> Gear`) |
| `/ge` | Short alias for `/gearexport` |
| `/gearexport My BIS Set` | Export gear with a custom set name |

The command auto-detects your target: if you have a **friendly player** targeted, it inspects and exports **their** gear; otherwise it exports your own. A custom name still applies to whichever character is exported.

A window will appear with the JSON output. Use `Ctrl+A` to select all, then `Ctrl+C` to copy it to your clipboard.

### Exporting a target

Inspecting another player is subject to the game's own limits:

- The target must be a **player** (not an NPC) of the **same faction**
- You must be within **inspect range** (~10 yards)
- Inspection is asynchronous and the server sends the equipment slot by slot, so the addon waits until the incoming set stops growing (up to 3 seconds) before showing the window — this avoids exporting a half-filled set

If no gear data comes back (out of range, wrong faction, target lost), a chat message explains why and nothing is exported.

## Import into Gear Planner

1. Run `/gearexport` in-game and copy the JSON
2. Open the [TurtleAtlasLoot Gear Planner](https://mrdobby92.github.io/TurtleAtlasLootWeb/gear-planner)
3. Use the **Import** feature and paste the JSON

## Example Output

```json
[
  {
    "name": "Xii Gear",
    "race": "Orc",
    "class": "Warrior",
    "level": 60,
    "slots": {
      "Back": {
        "itemId": 70008,
        "obtained": true
      },
      "Chest": {
        "itemId": 58030,
        "enchantId": 1891,
        "obtained": true
      },
      "Feet": {
        "itemId": 21388,
        "obtained": true
      },
      "Hands": {
        "itemId": 7457,
        "suffixId": 1199,
        "obtained": true
      },
      "Head": {
        "itemId": 29011,
        "enchantId": 2999,
        "gems": [24027, 24028],
        "obtained": true
      }
    }
  }
]
```

All equipped items are exported with `"obtained": true`. Empty slots are skipped. `enchantId` is only included for items that carry an enchant, and `suffixId` only for items with a random suffix (e.g. 7457 "of the Bear" reports suffixId 1199).

`gems` lists the itemIds of the gems socketed into the item, in socket order, and is only present when at least one socket is filled. Empty sockets are skipped, so a two-socket item with only the second socket filled reports a single-entry array. Vanilla items never have sockets, so the key never appears on a 1.12 export.

## Compatibility

| Client | Interface | Release asset |
|---|---|---|
| Vanilla WoW 1.12 | 11200 | `GearExport-<version>-vanilla.zip` |
| TBC 2.4.3 | 20400 | `GearExport-<version>-tbc.zip` |
| Burning Crusade Classic 2.5.x | 20504 | `GearExport-<version>-tbc.zip` |

One Lua source runs on all three. 2.4.3 predates the `.toc` suffix scheme and only reads `GearExport.toc`, so the TBC package ships that file at Interface 20400 alongside a `GearExport-BCC.toc` at 20504; Burning Crusade Classic prefers the suffixed file and 2.4.3 ignores it, so neither client reports the addon as out of date.

### How one source supports every client

Vanilla runs Lua 5.0 while TBC and BCC run Lua 5.1, and each client changed something the addon depends on. The code stays inside the subset all three share:

| Difference | 1.12 | 2.4.3 | 2.5.x | Approach |
|---|---|---|---|---|
| `#` length operator | not in Lua 5.0 | available | available | manual counters |
| `table.getn` | available | available | removed | manual counters |
| `string.gmatch` | `string.gfind` only | available | available | parsing built on `string.find` |
| Widget handler arguments | globals `this` / `arg1` | globals | `(self, elapsed)` | arguments with a fallback to the globals |
| `SetBackdrop` | on every frame | on every frame | needs `BackdropTemplate` | template applied only when it exists |
| Item link fields | 4 | 8 | 14+ | field count selects the layout |

The item link is the substantive difference. Vanilla encodes `itemId:enchant:suffix:unique`, while TBC inserts four gem fields ahead of the suffix (`itemId:enchant:gem1:gem2:gem3:gem4:suffix:unique`) and BCC appends level and bonus-id trailers after it. Since the itemId and enchant positions never move and the gem block only exists on the socketed layouts, the number of fields in the link is enough to pick the right one — no client version check is needed, and a server with a non-standard build number cannot break the parse.
