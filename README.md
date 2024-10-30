# VORP Inventory in Lua

## Requirements
- [VORP Core LUA](https://github.com/VORPCORE/vorp_core-lua)

## How to install
- Download the lastest version of `vorp_inventory`
- Copy and paste `vorp_inventory` folder to `resources/[VORP]essentials/vorp_inventory`
- Add `ensure vorp_inventory` to your `resource.cfg` file
- To change the language go to `languages/language.lua` and change the default language in config

## Extensive API
- Exports
- Events

## Features
- Weight inventory based `(with limit for items)`
- Unique weapons equip/unequip
- Weapons with serial numbers
- Weapons custom labels serial numbers and descriptions
- Weight for weapons and items
- Give ammo from your belt
- Drop/Give/Pick Up functions
- Usable items double click or right click
- KLS.
- Metadata for items
- Storage/Stashes API
- On respawn clear weapons items money ammo
- Jobs can hold more weapons
- Items and weapons with groups
- Item give on first connection and weapons and much more

## Extra Features
- Description of all items in DB
- Gold item like Dollars (You can give and drop item)
- Option to use Gold like Dollars, configurable in `config.lua` and `config.js`
- Added descriptions of each item in inventory, for items (desc is in DB), for weapons (desc is in `shared/weapons.lua`)

## DOCUMENTATION
Inventory API [Documentation](https://docs.vorp-core.com/api-reference/inventory)

## Credits
- To [Val3ro](https://github.com/Val3ro) for the initial work.
- To [Emolitt](https://github.com/RomainJolidon) for the conversion.
