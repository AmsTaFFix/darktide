# Changelog

All notable changes to this unofficial reupload of StimmCountdown are documented here. Base: upstream 1.4.1 by RRMLLNV.

## [Unreleased]

## 1.4.2 — 2026-10-30

### Fixed
- StimmCountdown spammed "attempt to call method 'remaining_ability_cooldown' (a nil value)" (hundreds of errors per session) after the game's 1.13 patch, which replaced ability cooldowns with a regenerating resource. The stimm timer now reconstructs remaining cooldown seconds from the new resource system, so it counts down correctly again and the errors are gone.
