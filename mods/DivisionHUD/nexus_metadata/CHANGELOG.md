# Changelog

All notable changes to this unofficial reupload of Division HUD are documented here. Base: upstream 1.11.0 by rrmllnv, community fixes by LucLeto.

## [Unreleased]

### Changed
- The mod page now spells out that the original Division HUD must be uninstalled first, since both install to the same mods\DivisionHUD\ folder, and names the "remaining_ability_cooldown (a nil value)" crash as the symptom of leftover old files.

## 1.11.0 — 2026-10-30

Community fixes by LucLeto.

### Fixed
- Division HUD crashed with "attempt to call method 'remaining_ability_cooldown' (a nil value)" after the game's 1.13 patch, which replaced ability cooldowns with a regenerating resource. The combat-ability bar and ability icon now read charge and cooldown state from the new ability resource system (mirroring the vanilla ability HUD), so the HUD no longer errors.
- Entering the Meat Grinder (and the shooting range and tutorial) crashed, because the HUD injected itself into those training-ground HUDs where the ability update then failed. Division HUD no longer adds itself to those screens.
- Tracked-deployable timers (Adamant blitz drone, Broker stimm field) are updated for the patch's projectile and talent changes, so they register and count down again.
