return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`auto_parry` encountered an error loading the Darktide Mod Framework.")

        new_mod("auto_parry", {
            mod_script = "auto_parry/scripts/mods/auto_parry/auto_parry",
            mod_data = "auto_parry/scripts/mods/auto_parry/auto_parry_data",
            mod_localization = "auto_parry/scripts/mods/auto_parry/auto_parry_localization",
        })
    end,
    packages = {},
}
