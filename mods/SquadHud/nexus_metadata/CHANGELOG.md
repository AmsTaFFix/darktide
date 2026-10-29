# Changelog

All notable changes to this unofficial reupload of Squad HUD are documented here. Base: upstream 1.5.0 by rrmllnv, community fix by LucLeto.

## 1.6.0 — 2026-10-29

### Added
- Compatibility with the True Level mod: when it is installed and enabled, the teammate level in the expanded view is taken from True Level and follows its display style (shown as a compact total so it fits the slot).
- An Integrations option to turn the True Level level source on or off; when off, Squad HUD uses its own level calculation.
- When the True Level compatibility is on, a level-30+ teammate's Havoc clearance rank is shown next to their level in the expanded view, with a nested Integrations toggle to turn it on or off.

## 1.5.1 — 2026-10-28

Patch 1.13 fix by LucLeto.

### Fixed
- Teammate combat-ability state stopped showing after game patch 1.13 — the game removed the old ability-cooldown methods and moved abilities to a regenerating resource. Cooldown and charge progress are now read from the new system, so teammate panels show ability state again.
- Reading ability tracking buffs no longer errors on teammates — a teammate's husk buff extension holds no buffs, so those buffs are now read only where they exist (the local player and solo-play bots), matching vanilla.

### Changed
- Per-frame work reduced: mod settings, inventory icons, and ammo values are cached instead of being looked up every frame, so the HUD costs less while the squad panels are on screen.
