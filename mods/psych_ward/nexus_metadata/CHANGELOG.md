# Changelog

All notable changes to this bugfix reupload of Psych Ward are documented here. Base: upstream 1.7.1.

## 1.7.3 - 2026-10-23

### Fixed

- Weapon re-blessing/crafting, inventory equip changes, and talent changes made from the mod's Character Select buttons (Crafting, Inventory, Talents) not taking effect in a mission until the affected gear was toggled off and back on from inside an actual session.

## 1.7.2 - 2026-10-23

### Fixed

- Vanilla "Reconnect to ongoing game session" popup showing on every mission start instead of only for a genuinely stale session.
- Reconnecting to a mission from character select getting stuck (and occasionally freezing the client) because a stale hub session was never cleared before rejoining.

## 1.7.1-bugfix1 — 2026-10-21

### Fixed
- Crash entering the Psykhanium (shooting range) from character select (`attempt to index field 'SINGLEPLAY_TYPES'`) after a game patch removed that constant — the shooting range now launches the same way the game's own training-grounds flow does.
- Crash when entering the Psykhanium right after finishing a mission, caused by a race between the old hub session tearing down and the new mechanism being installed.
