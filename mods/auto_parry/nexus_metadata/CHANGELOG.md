# Changelog

## [Unreleased]

### Added

- New mod: automatically presses the Dueling Sword's weapon special when a nearby enemy starts a melee attack, parrying it and triggering the free riposte counterattack.

### Fixed

- In Psykhanium/Meat Grinder, stopped reacting to enemy attacks aimed at someone/something else -- it now checks the attacker's actual target, not just distance.
- In Psykhanium/Meat Grinder, the parry no longer fires the instant a windup is seen -- it's now timed against the enemy's real hit, fixing both missed slow attacks (parry window closed before the hit landed) and wasted early presses.
