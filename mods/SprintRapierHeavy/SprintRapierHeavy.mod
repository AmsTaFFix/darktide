return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SprintRapierHeavy` encountered an error loading the Darktide Mod Framework.")

		new_mod("SprintRapierHeavy", {
			mod_script = "SprintRapierHeavy/scripts/mods/SprintRapierHeavy/SprintRapierHeavy",
			mod_data = "SprintRapierHeavy/scripts/mods/SprintRapierHeavy/SprintRapierHeavy_data",
			mod_localization = "SprintRapierHeavy/scripts/mods/SprintRapierHeavy/SprintRapierHeavy_localization",
		})
	end,
	packages = {},
}