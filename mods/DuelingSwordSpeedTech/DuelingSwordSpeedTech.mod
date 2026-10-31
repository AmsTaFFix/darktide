return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DuelingSwordSpeedTech` encountered an error loading the Darktide Mod Framework.")

		new_mod("DuelingSwordSpeedTech", {
			mod_script = "DuelingSwordSpeedTech/scripts/mods/DuelingSwordSpeedTech/DuelingSwordSpeedTech",
			mod_data = "DuelingSwordSpeedTech/scripts/mods/DuelingSwordSpeedTech/DuelingSwordSpeedTech_data",
			mod_localization = "DuelingSwordSpeedTech/scripts/mods/DuelingSwordSpeedTech/DuelingSwordSpeedTech_localization",
		})
	end,
	packages = {},
}