# AGENTS.md

## What this repo is

Personal Darktide mod workspace. Both mods under `mods/` are **vendored forks of mods by Fracticality** (`github.com/fracticality/darktide-mods`) carrying unofficial bugfixes that are submitted back upstream as PRs (psych_ward: PR #51, issue #49; crosshair_hud: PR #53, issue #52).

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

## Reference submodules

Both submodules are reference material, `shallow = true`, never edited or committed into.

- Grep `3rdparty/Darktide-Source-Code/scripts/` to verify a game class/method/field actually exists before hooking it.
- Grep `3rdparty/Darktide-Mod-Framework/dmf/` for the DMF API (`mod:hook`, `mod:persistent_table`, etc).
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

`CHANGELOG.md` is Keep-a-Changelog shaped, newest first: `## <version> — YYYY-MM-DD`, then `### Fixed`/`### Changed`/`### Added` with `-` bullets, one per user-visible effect (crash message or game patch where that's what the user recognizes, not commit hashes or file paths). Every version needs both a `CHANGELOG.md` entry and a matching `changelog/<version>.txt` plain-text slice with the same content (one item per line, no `-` dashes, no BBCode); the `.md` wins on conflict.

## Git

Conventional Commits, lowercase imperative subject, no trailing period, scope = mod dir in `snake_case`:

```
fix(psych_ward): drop stale hub session before rejoining a mission
```

Also `chore:` (unscoped) and the repo-custom `vendor: <mod> (upstream, pre-fix)` for importing pristine upstream code before fixes land on top. Branch `fix/<kebab-case-topic>`, merged with a non-fast-forward merge commit.

Commit only when asked. Never `git add -A`/`git add .` — `nexus/`, `.idea/`, `.serena/` must stay untracked, and there is no root `.gitignore` to protect you.

## Releasing

Page copy and changelog live in `mods/<mod>/nexus_metadata/` (see above). `nexus/<mod>_bugfix.zip` is hand-packed so it extracts to `mods/<mod>/`, built from `mods/<mod>/` only — never includes `nexus_metadata/`. Nexus mod ids: Psych Ward 89, Crosshair HUD 9. These pages are explicitly temporary — obsolete once Fracticality merges and releases the fix.
