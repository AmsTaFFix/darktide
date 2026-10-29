# Changelog

## [Unreleased]

### Added

- New mod: automatically presses the Dueling Sword's weapon special when a nearby enemy starts a melee attack, parrying it and triggering the free riposte counterattack.

### Fixed

- In Psykhanium/Meat Grinder, stopped reacting to enemy attacks aimed at someone/something else -- it now checks the attacker's actual target, not just distance.
- In Psykhanium/Meat Grinder, the parry no longer fires the instant a windup is seen -- it's now timed against the enemy's real hit, fixing both missed slow attacks (parry window closed before the hit landed) and wasted early presses.
- Stopped silently dropping a detected attack just because an earlier one was still on cooldown or already scheduled -- the mod now always schedules the more urgent of two threats instead of discarding the newer one outright.
- In Psykhanium/Meat Grinder, stopped missing a charging/moving attack's opening strike just because its windup started outside Trigger Range -- the attacker's confirmed target now matters more than its current distance, since it closes the gap while winding up anyway.
- Stopped dropping a scheduled parry just because the player's own weapon was mid-action at that exact instant -- it now holds the press through the whole window instead of trying once, letting the weapon's own input buffer catch the moment it becomes valid (the same way a manually mashed key would).
- Fighting several enemies at once could leave one of them completely unanswered for several seconds while the others kept winning the single pending slot -- now tracks up to 3 attackers independently, each on its own cooldown, instead of just one.
- In Psykhanium/Meat Grinder, enemies with multi-hit combo attacks (e.g. a cultist berzerker's flurry) only ever got their first hit parried -- later hits in the same combo now get covered too, by holding the parry window open for the whole combo instead of just its first hit.
