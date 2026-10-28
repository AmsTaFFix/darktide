local mod = get_mod("claude_bridge")

return {
  claude_bridge = {
    en = "Claude Bridge",
  },
  claude_bridge_description = {
    en = "Development-only mod: polls a request file on disk and executes it inside the game, for driving the game from an external agent. Not for release.",
  },
  poll_interval = {
    en = "Poll interval (seconds)",
  },
  echo_to_chat = {
    en = "Echo results to chat",
  },
  verbose_log = {
    en = "Verbose logging",
  },
}
