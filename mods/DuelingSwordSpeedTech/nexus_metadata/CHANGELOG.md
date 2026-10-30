# Changelog

## [Unreleased]

## 1.0.0 — 2026-10-30

### Added

- Automates the Dueling Sword sprint-attack-slide speed tech: sprint, throw an attack, slide right
  as speed peaks, chain straight into the next attack.
- Light technique (recommended): instant release, no charge needed, higher average speed than
  plain sprinting.
- Heavy technique (experimental): charges and releases a heavy for a bigger peak, but averages
  slower than plain sprinting due to the weapon's own minimum charge time — included for players
  who want to help tune it further.
- Settings grouped into Main, Heavy Technique, Light Technique, Slide & Glide Tuning, and Safety &
  Debug.
- A stamina safety floor that pauses the cycle rather than risk a glitched release on empty
  stamina.
- A debug trace tool (keybind) that dumps recent cycle data to a file for tuning.
