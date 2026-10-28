local mod = get_mod("claude_bridge")

return {
  name = mod:localize("claude_bridge"),
  description = mod:localize("claude_bridge_description"),
  is_toggleable = true,
  options = {
    widgets = {
      {
        setting_id = "poll_interval",
        type = "numeric",
        range = { 0.1, 2 },
        default_value = 0.25,
        decimals_number = 2,
        step_size_value = 0.05,
      },
      {
        setting_id = "echo_to_chat",
        type = "checkbox",
        default_value = false,
      },
      {
        setting_id = "verbose_log",
        type = "checkbox",
        default_value = false,
      },
    }
  }
}
