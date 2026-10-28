# Convenience targets for in-game verification. Windows + PowerShell 7 (pwsh).
# These wrap the scripts under tools/; see AGENTS.md "Claude Bridge" for details.

PWSH := pwsh -NoProfile -File
SHOT_OUT := tools/.cache/darktide-shot.png

.PHONY: shot deploy deploy-reload

# Capture the Darktide window to tools/.cache/darktide-shot.png (override: make shot OUT=path)
shot:
	$(PWSH) tools/screenshot.ps1 $(if $(OUT),-OutFile $(OUT),-OutFile $(SHOT_OUT))

# Copy mods into the game (no reload nudge). Subset: make deploy MODS=SquadHud
deploy:
	$(PWSH) tools/deploy.ps1 -SkipReload $(if $(MODS),-Mods $(MODS),)

# Copy mods into the game and drop a reload request (needs the game up + DMF developer_mode)
deploy-reload:
	$(PWSH) tools/deploy.ps1 $(if $(MODS),-Mods $(MODS),)
