<!-- Source of truth: jodok/dotfiles agents/claude.md — installed to ~/.claude/CLAUDE.md by install.sh. Edit in the repo, not here. -->

@~/.agents/global-rules.md

## Claude Code specifics

For the model rankings and when to use which model, see the global rules
above. Mechanics inside Claude Code:

- Codex-hosted OpenAI models (gpt-5.5, and newly GPT Sol) run via the
  openai/codex-plugin-cc plugin (it picks up `~/.codex/config.toml`).
  Delegate to them through the plugin's slash commands and skills, never
  through hand-rolled bash wrappers. In sessions where the plugin is not
  loaded (e.g. the desktop app), fall back to Claude subagents rather than
  wrapping the `codex` CLI by hand.
- Claude models (sonnet-5, opus-4.8, fable-5) run via the Agent tool's
  `model` parameter.
