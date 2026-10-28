return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`claude_bridge` encountered an error loading the Darktide Mod Framework.")

        new_mod("claude_bridge", {
            mod_script       = "claude_bridge/scripts/mods/claude_bridge/claude_bridge",
            mod_data         = "claude_bridge/scripts/mods/claude_bridge/claude_bridge_data",
            mod_localization = "claude_bridge/scripts/mods/claude_bridge/claude_bridge_localization",
        })
    end,
    packages = {}
}
