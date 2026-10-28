# Convenience targets for in-game verification. Windows + PowerShell 7 (pwsh).
# These wrap the scripts under tools/; see AGENTS.md "Claude Bridge" for details.

PWSH := pwsh -NoProfile -File
SHOT_OUT := tools/.cache/darktide-shot.png

.PHONY: shot deploy deploy-reload task finish

# Capture the Darktide window to tools/.cache/darktide-shot.png (override: make shot OUT=path)
shot:
	$(PWSH) tools/screenshot.ps1 $(if $(OUT),-OutFile $(OUT),-OutFile $(SHOT_OUT))

# Copy mods into the game (no reload nudge). Subset: make deploy MODS=SquadHud
deploy:
	$(PWSH) tools/deploy.ps1 -SkipReload $(if $(MODS),-Mods $(MODS),)

# Copy mods into the game and drop a reload request (needs the game up + DMF developer_mode)
deploy-reload:
	$(PWSH) tools/deploy.ps1 $(if $(MODS),-Mods $(MODS),)

# Start a task: open an issue + create a worktree branch (see AGENTS.md "Development workflow")
# Usage: make task TYPE=feat TOPIC=havoc-button TITLE="Add a Havoc button"
task:
	$(PWSH) tools/new-task.ps1 -Type $(TYPE) -Topic $(TOPIC) $(if $(TITLE),-Title "$(TITLE)",) $(if $(BODY),-Body "$(BODY)",)

# Finish a task: push + open PR; merges + cleans up only with VERIFIED=1
# Usage: make finish ISSUE=7 VERIFIED=1
finish:
	$(PWSH) tools/finish-task.ps1 $(if $(ISSUE),-Issue $(ISSUE),) $(if $(VERIFIED),-Verified,)
