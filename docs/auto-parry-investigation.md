# auto_parry investigation (discontinued)

A mod that auto-pressed the Dueling Sword's (`combatsword_p3`) weapon special
(`action_parry_special`) when a nearby enemy began a melee attack, so the attack got parried and
the free riposte (`action_attack_special_riposte`) fired. Built and iteratively live-debugged
across issue #16 (initial build, PR #17, merged), issue #18 (wrong-target filtering, PR #19, never
merged), and this removal (issue #20). Discontinued because its usefulness turned out to be capped
by Darktide's network architecture, not by anything the mod itself could fix. This doc records why,
so a future session doesn't re-attempt the same investigation blind.

## What worked: Psykhanium / Meat Grinder (the player is the host)

In these two training areas the local player is the authoritative simulator
(`host_singleplay = true` in their `game_mode_settings_*.lua`), so the enemy behavior tree runs
locally and is directly hookable. Over several live-debugged iterations the mod reached what the
user confirmed was near-flawless behavior there:

- **Detection**: hooked `BtMeleeAttackAction._start_attack_anim` (not `.enter` — `.enter` fires for
  any nearby minion's attack regardless of target; `_start_attack_anim` is called synchronously
  from inside `.enter()` and, by the time it returns, has already picked the attack variant and
  computed `scratchpad.attack_timing`/`.start_sweep_t` — the absolute timestamp of the real hit —
  plus hands over the real `target_unit` as a parameter).
- **Scheduling**: pressed `weapon_extra_pressed` not the instant the windup was seen, but scheduled
  against `damage_t - pre_hit_margin`, and *held* the input true for the whole window instead of a
  single frame — letting the engine's own `special_action` input buffer (`buffer_time = 0.2`,
  re-evaluated against the real chain/validity rules every fixed frame) catch the exact valid
  moment, the same way a real mashed key would, instead of the mod deciding validity itself in one
  shot.
- **Target filtering**: rejected attacks whose `target_unit` wasn't the local player — `.enter()`-
  only detection can't do this; `_start_attack_anim`'s own parameter can.
- **Multi-enemy**: tracked up to 3 concurrent attacker threats independently (one global pending
  slot starved whichever attacker lost the "soonest real hit" contest for seconds at a time in a
  3-enemy fight, confirmed live).
- **Multi-hit combos**: a combo (e.g. a cultist berzerker's `attack_move_combo_01_fast`, 7 hits
  spanning 0.67s-2.95s) only calls `_start_attack_anim` once, so the window was extended to the
  combo's *last* hit (read from `scratchpad.attack_timings`/`.attack_sweep_timings`, already
  available at detection time) instead of just the first, relying on `special_action`'s own
  `chain_time = 0.9` re-arm (valid from inside an already-running parry) to catch each later hit.
- **Interrupt cancellation**: hooked `BtMeleeAttackAction.leave` (NOT the base `BtNode.leave`,
  which is shadowed by a per-instance closure and never actually fires for subclasses) to drop a
  tracked threat the instant the attacker's own attack action ends for any reason — stagger,
  target switch, death, or finishing normally — so interrupting an attacker (e.g. by hitting it)
  stopped the character uselessly re-raising the sword for an attack that no longer existed.

## What didn't work: real missions (the client is never the host)

### Finding 1: real missions are always dedicated-server — confirmed, no exceptions

Darktide's hosting model is not negotiated per-match; it's a static property of the game mode.
- `host_singleplay` is `true` only for `training_grounds`, `shooting_range`, `prologue`,
  `prologue_hub`, and the dev-only `hub_singleplay` — and `false` for every real-mission mode:
  `coop_complete_objective`, `survival`, `expedition`, plus `hub` (the Mourningstar) and `default`.
  (`scripts/settings/game_mode/game_mode_settings_*.lua`, full table in
  `game_mode_settings.lua:61-73`.)
- The only session-boot classes that exist are `SingleplayerSessionBoot` (→ `HOST_TYPES.singleplay`,
  used for Psykhanium/Meat Grinder), `PartyImmateriumHubSessionBoot` (→ `hub_server`), and
  `PartyImmateriumMissionSessionBoot` (→ `mission_server`) —
  `scripts/managers/multiplayer/multiplayer_session_manager.lua:136-164`. The mission boot
  (`party_immaterium_mission_session_boot.lua:39-136`) fetches server details from Fatshark's
  backend and hard-fails (`"server_mismatch"`) if the far end isn't a `mission_server`; it always
  ends in `ConnectionClient`, never a host.
- `ConnectionHost` (the class a listen-server/peer-host client would need) does not exist anywhere
  in the client scripts — only `ConnectionClient`/`ConnectionSingleplayer` do. The
  `HOST_TYPES.player` enum value (the Vermintide-2-style listen-server case) is defined but never
  assigned anywhere in the client code.
- Solo missions and private lobbies don't change this: `fetch_queue_ticket_single_player` still
  requests an AWS mission-server alias (`scripts/backend/matchmaker.lua:173-187`), and
  `GameplaySession`'s own session-creation payload is literally `serverDetails = { type =
  "dedicated", ... }` (`scripts/backend/gameplay_session.lua:81-92`). Bots are spawned
  server-side; they don't imply local simulation.
- No host migration exists in the codebase — losing the mission server disconnects you back to the
  hub, it never promotes the client to authority.

Consequence: `BtMeleeAttackAction._start_attack_anim`/`.leave` (and everything built on them) will
never fire on a real mission client. There is no reachable code path in a retail client, in any
mode, that changes this.

### Finding 2: no other client-visible signal closes the gap generally

The only signal a non-host client gets at all is `rpc_minion_anim_event`
(`scripts/extension_systems/animation/animation_system.lua`) — an animation *event index*, no
name, no semantic meaning, broadcast for literally any minion animation, not just attacks. Six
other candidate signals were checked and ruled out as general-purpose replacements:

| Signal | Verdict |
|---|---|
| `MinionAttackIntensityExtension` | Host-only — only added in `minion_unit_template.lua`'s `local_init`, absent from `husk_init` (confirmed for minions specifically, not just players). |
| `rpc_start_template_effect` / `effect_template_start_timings` | Real and client-visible (carries the attacking unit + a windup-relative timestamp), but `effect_template_start_timings` is only set on ~5 breeds total (daemonhosts, captains, the ogryn houndmaster) — absent from every ordinary infantry breed (renegades, cultists, infected). |
| `Vo.player_vo_enemy_attack_event` (the "watch out" bark) | Only fires for multi-hit attacks, the listener is a uniformly random alive player (not the target), and the RPC that reaches the client (`rpc_play_dialogue_event`) carries the *speaker*, not the attacker or target — not even usable as a weak corroborator. |
| Smart-tag / `unit_threat` world marker | 100% player-initiated (every path requires a `tagger_unit`); no AI-driven "this enemy is engaged" signal exists behind it. |
| `GameSession.set_game_object_field` from behavior-tree actions | Full inventory taken across `extension_systems/behavior/`; nothing generic for ordinary melee. `weapon_intensity` is written from the generic `BtMeleeAttackAction` code but only flagged on `renegade_executor`'s 4 actions. |
| Client-side anim index→name reconstruction | **Partially possible, not pursued.** `Unit.has_animation_event` only returns a bool, so it can't build the table; only `Unit.animation_event(unit, name)` returns an index, and it also *plays* the event. Indices are deterministic per `breed.state_machine` (confirmed via `animation_system_tests.lua` and the husk anim-replay mechanism, which only works because sender/receiver index spaces match), so a table built once per breed by spawning a disposable off-screen unit of that breed and probing each candidate attack-event name from `BreedActions` would be valid for every real unit of that breed. This is the one lever that could have meaningfully improved real-mission detection (real attack/non-attack discrimination, real per-hit timing, real combo coverage) — but it requires spawning a unit client-side (a new risk category this mod never needed before), and even working perfectly it would still leave the two gaps nothing here closes: which player the attack is aimed at, and clean cancellation when the attacker is interrupted (both only available via host-side BT/blackboard data). Declined as disproportionate to what it would still not fix. |

## Final verdict

Real-mission auto-parry detection is capped by Darktide's client/server architecture, not by
engineering effort on this mod's part — there is no further investigation that changes the
dedicated-server finding, and no remaining signal (short of client-side unit spawning, which still
wouldn't close the target/interrupt gaps) brings it close to the Psykhanium-quality experience.
Discontinued rather than shipped as a materially worse real-mission mode under the same name.

See GitHub issues #16, #18, #20 and PRs #17 (merged), #19 (closed, not merged) for the full
session-by-session history this doc summarizes.
