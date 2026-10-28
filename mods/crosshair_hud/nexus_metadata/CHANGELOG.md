# Changelog

All notable changes to this bugfix reupload of Crosshair HUD are documented here. Base: upstream 2.0.5b.

## 2.0.6 — 2026-10-18

### Fixed
- Ability/stimm cooldown crash after game patch 1.13 (`attempt to call method 'remaining_ability_cooldown' (a nil value)`) — the game removed the old cooldown methods and moved abilities to a regenerating resource; timers are now computed from the new system.
- Cooldown timers show exact seconds again, using the same math as the game itself, including while spectating a downed teammate.
- Cooldown helper no longer crashes on abilities that use husk ability extensions.
- Archetype icon crash in missions after game patch 1.13 (`attempt to index field 'archetype_font_icon_simple' (a nil value)`) — the game removed that icon table; the ally panel and coherency indicators now fall back to `archetype_font_icon`.
