<!-- Source of truth: jodok/dotfiles agents/claude.md — installed to ~/.claude/CLAUDE.md by install.sh. Edit in the repo, not here. -->

@~/.agents/global-rules.md

## Claude Code specifics

For the model rankings and when to use which model, see the global rules
above. Mechanics inside Claude Code:

- gpt-5.5 runs via the openai/codex-plugin-cc plugin (it picks up
  `~/.codex/config.toml`). Delegate to it through the plugin's slash
  commands and skills, never through hand-rolled bash wrappers.
- Claude models (sonnet-5, opus-4.8, fable-5) run via the Agent tool's
  `model` parameter.
