# AGENTS.md

## What this repo is

Personal Darktide mod workspace. The mods under `mods/` are **vendored forks of mods by other authors**, carrying unofficial bugfixes:

- `psych_ward`, `crosshair_hud` — forks of mods by **Fracticality** (`github.com/fracticality/darktide-mods`), fixes submitted back upstream as PRs (psych_ward: PR #51, issue #49; crosshair_hud: PR #53, issue #52).
- `SquadHud` — fork of the Squad HUD mod by **rrmllnv** (`github.com/rrmllnv/darktide-mods`, Nexus mod 844), reviving it after the author went inactive. The bundled patch 1.13 fix is a community fix by **LucLeto**, vendored as-is; there is no upstream PR for it yet.

Consequence for agents: **keep diffs minimal and upstream-mergeable.** Fix the bug and stop — no restyling, no refactors, no renames, no "while I'm here" cleanup. A smaller diff merges faster upstream.

## Layout

```
mods/<name>/<name>.mod                                   DMF manifest (4-space indent)
mods/<name>/scripts/mods/<name>/<name>.lua                hooks + logic (2-space indent)
mods/<name>/scripts/mods/<name>/<name>_data.lua           options schema
mods/<name>/scripts/mods/<name>/<name>_localization.lua   strings
mods/<name>/nexus_metadata/VERSION                        current Nexus version, single line
mods/<name>/nexus_metadata/CHANGELOG.md                   release history, source of truth
mods/<name>/nexus_metadata/short_description.txt          Nexus mod-page summary blurb, plain text
mods/<name>/nexus_metadata/full_description.txt           Nexus "Description" tab, BBCode
mods/<name>/nexus_metadata/changelog/<version>.txt        per-version changelog for that file upload, plain text
3rdparty/Darktide-Source-Code/   submodule, 203 MB decompiled game source — READ ONLY
3rdparty/Darktide-Mod-Framework/ submodule, DMF — READ ONLY
nexus/                           untracked Nexus publishing staging (.zip only)
```

Mods:
- **psych_ward** — adds Hub features (Mortis Trials, Mission Board, vendors, contracts, crafting, inventory, cosmetics, penances, Psykhanium) to the Character Select menu.
- **crosshair_hud** — custom HUD element with Toughness/Health/Coherency/Ammo/Reload/Grenade/Ability indicators near the crosshair.
- **SquadHud** — four compact strike-team panels (health, toughness, statuses, distance, resources, loadout) replacing the vanilla squad UI. Note: dir is PascalCase `mods/SquadHud/` (not snake_case), matching its upstream dir and `new_mod("SquadHud")` id; a multi-file mod under `scripts/mods/SquadHud/`. Commit scope is written `squad_hud` per the Git convention below.

## Reference submodules

All submodules are reference material, `shallow = true`, never edited or committed into.

- Grep `3rdparty/Darktide-Source-Code/scripts/` to verify a game class/method/field actually exists before hooking it.
- Grep `3rdparty/Darktide-Mod-Framework/dmf/` for the DMF API (`mod:hook`, `mod:persistent_table`, etc).
- `3rdparty/Zombine-Darktide-Mods/true_level/` — Zombine's True Level mod, the source for SquadHud's optional True Level integration (`get_mod("true_level")`: `get_true_levels(character_id)`, `is_enabled()`, `get("display_style")`).
- `3rdparty/` is 200+ MB and will dominate a repo-wide grep — scope searches to `mods/` by default.

## Lua conventions

All observed in-tree; follow them, don't introduce new patterns.

- Every file starts `local mod = get_mod("<mod_name>")`.
- `snake_case` for locals/functions/setting ids. Game modules bound to PascalCase locals: `local ProfileUtils = require("scripts/utilities/profile_utils")`.
- Leading `_` for file-local state/helpers (`_setup_complete`, `_create_button_offset_setting`), `_cb_` prefix for callbacks.
- Hooks registered at file top level, three flavours:
  - `mod:hook(CLASS.X, "method", function(func, self, ...) ... return func(self, ...) end)` — wrapping/short-circuiting.
  - `mod:hook_safe(CLASS.X, "method", function(self) ... end)` — post-hook, no `func`.
  - `mod:hook_require("scripts/settings/...", fn)` — patches data tables on load; note the `templates = templates.__data or templates` idiom (`crosshair_hud.lua:61`).
- Intra-mod file loading is `mod:io_dofile("<mod>/scripts/mods/<mod>/<path>")`, **not** `require` (`crosshair_hud.lua:3`, `psych_ward.lua:6`).
- Persistent state: `mod.context = mod:persistent_table("mod_context", { ... })`.
- Lifecycle: `function mod.on_game_state_changed(status, state)`.
- Logging/UX: `mod:warning(...)`, `mod:error(...)`, `mod:notify(...)` — printf-style format args.
- Settings: `*_data.lua` returns `{ name, description, is_toggleable, options = { widgets = {...} } }`. Widget fields: `setting_id, type, default_value, range, decimals_number, step_size_value, options, sub_widgets`. Read with `mod:get(id)`, write with `mod:set(id, value)`. `crosshair_hud` runs `settings/migrations.lua` at data load — if a `setting_id` or its shape changes, add a migration there.
- Localization: table per key, `en` mandatory, optional `ru`, `ja`, `ko`, `zh-cn`, `zh-tw`. Keys mirror setting ids. Global strings via `mod:add_global_localize_strings`.
- Leave existing `--TODO:` comments and commented-out experiment blocks alone — upstream-diff hygiene.

## Build & test

No build, no lint, no CI, no test suite. Don't invent one.

Verification is manual, in-game: copy/symlink `mods/<name>/` into `<Darktide>\mods\`, ensure `<name>` is listed in `<Darktide>\mods\mod_load_order.txt`, Darktide Mod Loader + DMF enabled, launch, exercise the affected screen. If you can't do this, say so instead of claiming the fix works.

`tools/deploy.ps1` + `tools/claude_bridge/` give an agent a verification path that doesn't need the user — see **Claude Bridge** below. This verification is the gate that decides whether a PR self-merges — see **Development workflow**.

## Claude Bridge — in-game verification without the user

`tools/claude_bridge/` is a dev-only DMF mod (not one of the vendored forks — never put it in
`mods/`, a `nexus/*.zip`, or an upstream PR, and don't enable it in a normal play session). It
polls a request file on disk and runs it inside the running game, so an agent can execute Lua,
read live game state, or trigger a mod reload, and read the result back from a file — no
screenshots, no input synthesis, no asking the user to click anything.

### Deploy

```powershell
tools/deploy.ps1
```

Copies `mods/psych_ward`, `mods/crosshair_hud`, `mods/SquadHud`, and `tools/claude_bridge` into
`<Darktide>\mods\` (excluding `nexus_metadata/`), adds any missing name to
`<Darktide>\mods\mod_load_order.txt`, and drops a `reload` request so a running game picks up
the change. Defaults assume the game is installed at
`C:\Program Files (x86)\Steam\steamapps\common\Warhammer 40,000 DARKTIDE`; pass `-GameDir` if
not. Pass `-Mods <name>` to deploy a subset, `-SkipReload` to skip the reload nudge.

**First-ever deploy on a machine, or any time `claude_bridge` was just added to
`mod_load_order.txt`, needs one game restart** — mods only load at launch, so a reload request
sent before that restart has nothing to receive it. Check
`%APPDATA%\Fatshark\Darktide\console_logs\console-*.log` (newest file) for
`Loading mod claude_bridge` to confirm it's loaded; after that, `reload` works without
restarting.

### Talking to it

Working directory: `%APPDATA%\Fatshark\Darktide\claude_bridge\`.

Write `request.lua` (write to `request.tmp` then rename over it, so the mod never reads a
half-written file — the mod polls every `poll_interval` seconds, default 0.25):

```lua
return { id = 1, cmd = "eval", code = "return 1 + 1" }
```

`id` must be a plain increasing number — the mod only acts on `id` greater than the last one it
handled (tracked in a `persistent_table`, so it survives a mod reload too) — so bump it on every
request, don't reuse or reset it. The mod deletes `request.lua` once it's handled, and on a game
restart (when the `persistent_table` resets to 0) it re-seeds the last handled id from
`response.txt`'s `id:` line — so don't hand-delete `response.txt` while `request.lua` still
exists, or a stale request could be replayed. Then poll-read `response.txt` (plain text, not JSON):

```
id: 1
ok: true
value: 2
```

On failure: `ok: false` plus an `error:` line with the compile or runtime message. A table
result is written via DMF's own `mod:dtf` to `<Darktide>\binaries\dump\claude_<id>.json`, and
the response carries `dump: dump/claude_<id>.json` (relative to `binaries/`) instead of a
`value:` line.

### Commands (`cmd` field)

| `cmd` | Fields | Does |
| --- | --- | --- |
| `eval` | `code` (Lua, must `return` something) | Runs it, `value:` for a scalar result, `dump:` for a table. |
| `dump` | `code`, optional `depth` | Like `eval` but always writes a dump file, even for a scalar. |
| `state` | — | Dumps game mode, mechanism, UI state name, and (if a player exists) health/toughness percent and alive flag. See `tools/claude_bridge/scripts/mods/claude_bridge/bridge/state_probe.lua` for exact fields. |
| `notify` | `text` | Puts an on-screen toast — useful to ask the user "is this what you expected" without them typing anything. |
| `reload` | — | Schedules a DMF mod reload (so edits to any mod's `.lua` take effect without restarting). Requires DMF's `developer_mode` setting to be on; responds `ok: false` with that reason if it isn't. The response is written *before* the reload tears mods down, so it always arrives. |
| `screenshot` | optional `output_dir`, `filename` | Best-effort only — wraps the one in-engine capture call found in the decompiled source (`FrameCapture.screen_shot`), unverified in a retail build. `ok: false` if unavailable. |

Same registry is reachable by hand in-game as a chat command: `/claude eval return 1+1`.

### Screenshots

The bridge `screenshot` command does **not** work in retail (`FrameCapture.screen_shot`
is unavailable), and a plain desktop grab misses the game when it is alt-tabbed or on another
monitor. Use `tools/screenshot.ps1` instead — it captures the Darktide window itself:

```
pwsh -NoProfile -File tools/screenshot.ps1            # -> tools/.cache/darktide-shot.png
pwsh -NoProfile -File tools/screenshot.ps1 -OutFile C:\tmp\shot.png
make shot                                             # same, via the Makefile
```

It is per-monitor DPI-aware, finds the window by process name (`Darktide`), tries
`PrintWindow` with `PW_RENDERFULLCONTENT` first (grabs a background window without stealing
focus), and falls back to foreground + GDI copy only if that frame is blank. `tools/.cache/`
is a scratch dir — keep it untracked, never commit shots.

Exclusive-fullscreen caveat: if captures come back black, set Darktide to Borderless/Windowed.
DSR caveat: the capture shows the actual output surface, so if the game renders above the
monitor's native resolution (NVIDIA DSR / a supersampled resolution), the frame is downsampled
and HUD placed in the lower/right design area can sit off the visible surface — that is a video
config, not a mod bug. Verify HUD mods at the monitor's native resolution (use DLSS, not DSR,
for extra sharpness).

### Troubleshooting

- No `response.txt` appears: confirm `Darktide.exe` is running and the newest console log shows
  `claude_bridge` loaded (see above); the mod can only poll while the game is up.
- `reload` returns `ok: false`: enable DMF's `developer_mode` option in the in-game DMF options
  menu (character select → Darktide Mod Framework) once; it's a per-install setting that
  persists after that.
- Editing `tools/claude_bridge/*.lua` itself requires `tools/deploy.ps1` + `reload` (or a
  restart) same as any other mod — it does not hot-reload itself just because its source changed
  on disk.

## Nexus metadata

Each mod's `nexus_metadata/` holds everything that gets pasted into its Nexus page. Nothing Nexus-facing lives anywhere else; these paths are never shipped in `nexus/<mod>_bugfix.zip` and never included in an upstream PR.

```
mods/<name>/nexus_metadata/
  VERSION                  single line, e.g. 2.0.6 — no "v" prefix
  CHANGELOG.md              source of truth, newest version first
  short_description.txt     Nexus mod-page summary blurb, plain text, no BBCode
  full_description.txt      Nexus "Description" tab, BBCode
  changelog/<version>.txt   per-version changelog for that file upload, plain text
```

`full_description.txt` is **BBCode**, not Markdown, despite the `.txt` extension — Nexus has no dedicated file format; the extension is deliberate, don't "fix" it to `.md`. Never put `#`, `**`, or `-` lists in it. Tag subset actually used: `[b] [i] [u] [size=N] [color=#hex] [url=...] [list] [*]`. No unclosed tags, no space before a closing tag (`[url=x]name [/url]` is wrong). English only.

`changelog/<version>.txt` (the per-upload changelog Nexus attaches to a file) is **plain text, not BBCode** — no tags, no `[list]`/`[*]`, no `-`/`*` dashes. One fixed/changed/added item per line, nothing else on that line. English only.

`full_description.txt` sections, in this order, each a `[size=4][b]Name[/b][/size]` header followed by a `[color=#D4D4D8]...[/color]` body: Description, Installation instructions, Main features, Requirements, Shout outs. Don't enumerate individual fixed bugs here — that list lives only in `changelog/<version>.txt` (Nexus attaches a changelog to each file upload, there is no single aggregate tab); the description just points there, so a fix is never typed in two places.

`short_description.txt` is one plain-sentence blurb (no BBCode, no section headers) shown on the mod-page card — keep it under ~250 characters and free of per-bug detail for the same reason.

`VERSION` = upstream Fracticality version plus our own bump, e.g. `2.0.6` on top of upstream `2.0.5b`. The user supplies the upstream base and when to bump — never invent or auto-bump a version.

`CHANGELOG.md` is Keep-a-Changelog shaped, newest first: `## <version> — YYYY-MM-DD`, then `### Fixed`/`### Changed`/`### Added` with `-` bullets, one per user-visible effect (crash message or game patch where that's what the user recognizes, not commit hashes or file paths).

Unreleased work accumulates under a `## [Unreleased]` section pinned at the very top of `CHANGELOG.md`, above the newest released version, with the same `### Fixed`/`### Changed`/`### Added` subsections and `-` bullets. **Every merged change records its user-visible effect under `## [Unreleased]` as part of that change — do not bump `VERSION` and do not write a `changelog/<version>.txt` slice per fix.** This applies to all mods (`psych_ward`, `crosshair_hud`, `SquadHud`). Cutting a release is a separate, explicit step the user asks for (see **Releasing**): only then does `## [Unreleased]` become `## <version> — YYYY-MM-DD`, `VERSION` get bumped, and a matching `changelog/<version>.txt` plain-text slice get written with that version's items. A released version always needs both its `CHANGELOG.md` entry and its matching `changelog/<version>.txt` slice (one item per line, no `-` dashes, no BBCode); the `.md` wins on conflict.

## Development workflow

How a non-trivial tracked change gets made here: **issue → worktree branch → PR → gated merge.**
Applies to new features and standalone fixes alike. This governs *process*; the upstream-diff
hygiene from "What this repo is" still governs *mod code content* (keep the diff minimal and
upstream-mergeable). Trivial repo chores — a docs typo, a metadata tweak — may skip the ceremony
at the user's discretion.

Turnkey helpers wrap steps 1–2 and 4–5: `tools/new-task.ps1` (`make task`) and
`tools/finish-task.ps1` (`make finish`). Steps below show both the helper and the raw commands.

1. **Issue first.** Every piece of work opens with a GitHub issue — title = the user-visible
   outcome, body = problem + acceptance. `gh issue create` (templates under `.github/ISSUE_TEMPLATE/`),
   or `tools/new-task.ps1` does it for you. Note the issue number `N`.

2. **Worktree + branch.** Branch `<type>/<kebab-topic>`, `<type>` ∈ `feat` / `fix` / `chore`.
   Work in a dedicated **external sibling worktree**, never on `main` directly:

   ```powershell
   git worktree add -b feat/<topic> ../darktide-wt/feat-<topic> main
   ```

   (The submodules under `3rdparty/` are `shallow=true` reference-only and shared across
   worktrees — no re-init needed.) `tools/new-task.ps1 -Type feat -Topic <topic> -Title "..."`
   creates the issue, branch, and worktree in one shot and prints the `cd` target.

3. **Implement + verify.** Make the change inside the worktree. Verify on a live client wherever
   possible — `tools/deploy.ps1` → `reload` via **Claude Bridge** → exercise the affected screen →
   `tools/screenshot.ps1` or Bridge `state`/`eval` (see **Build & test** and **Claude Bridge**).

4. **Commit + PR.** Commit per the **Git** convention (Conventional Commits, `snake_case` scope,
   `Co-Authored-By:` attribution line). Push, then `gh pr create`. PR body ends with `Closes #N`
   and the `🤖 Generated with [Claude Code]` attribution line; fill the
   `.github/pull_request_template.md` checklist. `tools/finish-task.ps1` pushes and opens the PR.

5. **Gated merge — the decision rule.**
   - **Verified on a live Darktide client** → merge the PR yourself with a non-ff merge commit to
     match repo style, then clean up the worktree:

     ```powershell
     gh pr merge --merge --delete-branch
     git worktree remove ../darktide-wt/feat-<topic>
     ```

     `tools/finish-task.ps1 -Verified` does the merge + cleanup.
   - **Could not verify on a live client** (game not running, screen unreachable, headless) →
     **do not self-merge.** Report what you did and could not verify, and ask the user whether to
     merge anyway or hold. (Same spirit as "If you can't do this, say so instead of claiming the
     fix works" in **Build & test**.) `tools/finish-task.ps1` without `-Verified` stops at the
     open PR and says so.

## Git

Conventional Commits, lowercase imperative subject, no trailing period, scope = mod dir in `snake_case`:

```
fix(psych_ward): drop stale hub session before rejoining a mission
```

Also `chore:` (unscoped) and the repo-custom `vendor: <mod> (upstream, pre-fix)` for importing pristine upstream code before fixes land on top. Branch `<type>/<kebab-case-topic>` (`feat`/`fix`/`chore`), worked in its own worktree and merged with a non-fast-forward merge commit — see **Development workflow** for the full issue→PR→merge loop.

Commit only when asked. Never `git add -A`/`git add .` — `nexus/`, `.idea/`, `.serena/` must stay untracked, and there is no root `.gitignore` to protect you.

## Releasing

Page copy and changelog live in `mods/<mod>/nexus_metadata/` (see above). `nexus/<mod>_bugfix.zip` is hand-packed so it extracts to `mods/<mod>/`, built from `mods/<mod>/` only — never includes `nexus_metadata/`. Nexus mod ids: Psych Ward 89, Crosshair HUD 9. These pages are explicitly temporary — obsolete once Fracticality merges and releases the fix.

Cutting a release (only when the user asks, with the version they supply): rename the `## [Unreleased]` section in `CHANGELOG.md` to `## <version> — YYYY-MM-DD`, bump `VERSION` to match, and write `changelog/<version>.txt` as a plain-text slice of exactly that version's items (one per line, no `-` dashes, no BBCode). Leave a fresh empty `## [Unreleased]` at the top for the next change.
