# GearExport

A vanilla WoW addon that exports your currently equipped gear as JSON, compatible with the [TurtleAtlasLoot Gear Planner](https://mrdobby92.github.io/TurtleAtlasLootWeb/gear-planner).

Browse and share exported characters at the [Tortoise DB Viewer](https://xian55.github.io/tortoise-db-viewer/?characters).

## Features

- Exports all 17 equipment slots (Head, Neck, Shoulder, Back, Chest, Wrist, Hands, Waist, Legs, Feet, Finger 1 & 2, Trinket 1 & 2, Main Hand, Off Hand, Ranged)
- Includes the character's race, class, level, applied item enchants, and any random suffix (e.g. "of the Bear")
- Outputs JSON in the exact format the Gear Planner expects for import
- Provides a scrollable, copy-friendly text window in-game
- Supports custom set names

## Installation

1. Download or clone this repository
2. Copy the `GearExport` folder into your `Interface/AddOns/` directory
3. Restart the game or type `/reload`

## Usage

| Command | Description |
|---|---|
| `/gearexport` | Export gear with default name (`<CharacterName> Gear`) |
| `/ge` | Short alias for `/gearexport` |
| `/gearexport My BIS Set` | Export gear with a custom set name |

A window will appear with the JSON output. Use `Ctrl+A` to select all, then `Ctrl+C` to copy it to your clipboard.

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
      "Waist": {
        "itemId": 7457,
        "suffixId": -12,
        "obtained": true
      },
      "Feet": {
        "itemId": 21388,
        "obtained": true
      }
    }
  }
]
```

All equipped items are exported with `"obtained": true`. Empty slots are skipped. `enchantId` is only included for items that carry an enchant, and `suffixId` only for items with a random suffix (e.g. "of the Bear"). Random suffix IDs may be negative.

## Compatibility

- **Client:** Vanilla WoW 1.12
- **Interface version:** 11200
