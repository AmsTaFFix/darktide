# Changelog

All notable changes to this bugfix reupload of Squad HUD are documented here. Base: upstream 1.5.0 by rrmllnv, community fix by LucLeto.

## 1.5.1 — 2026-10-28

### Fixed
- Teammate combat-ability state stopped showing after game patch 1.13 — the game removed the old ability-cooldown methods and moved abilities to a regenerating resource. Cooldown and charge progress are now read from the new system, so teammate panels show ability state again.
- Reading ability tracking buffs no longer errors on teammates — a teammate's husk buff extension holds no buffs, so those buffs are now read only where they exist (the local player and solo-play bots), matching vanilla.

### Changed
- Per-frame work reduced: mod settings, inventory icons, and ammo values are cached instead of being looked up every frame, so the HUD costs less while the squad panels are on screen.
