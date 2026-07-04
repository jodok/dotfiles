<!-- Source of truth: jodok/dotfiles agents/claude.md — installed to ~/.claude/CLAUDE.md by install.sh. Edit in the repo, not here. -->

@~/.agents/global-rules.md

## Picking the right models for workflows and subagents

Rankings, higher = better. Cost reflects what I actually pay (OpenAI has
really generous limits), not list price. Intelligence is how hard a problem
you can hand the model unsupervised. Taste covers UI/UX, code quality, API
design, and copy.

| model    | cost | intelligence | taste |
|----------|------|--------------|-------|
| gpt-5.5  | 9    | 8            | 5     |
| sonnet-5 | 6    | 5            | 7     |
| opus-4.8 | 4    | 8            | 8     |
| fable-5  | 2    | 9            | 9     |

How to apply:

- These are defaults, not limits. Standing permission to override them: if a
  cheaper model's output doesn't meet the bar, redo the work with a smarter
  model without asking. Judge the output, not the price tag — escalating
  costs less than shipping mediocre work.
- Cost is a tie-breaker only; when axes conflict for anything that ships,
  intelligence > taste > cost.
- Bulk/mechanical work (clear-spec implementation, data analysis,
  migrations): gpt-5.5 — cheap and token-efficient.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans and implementations: fable-5 or opus-4.8, optionally
  gpt-5.5 as an extra independent perspective.
- Never use Haiku.
- Mechanics: gpt-5.5 runs via the openai/codex-plugin-cc plugin (it picks up
  `~/.codex/config.toml`). Delegate to it through the plugin's slash
  commands and skills, never through hand-rolled bash wrappers. Claude
  models (sonnet-5, opus-4.8, fable-5) run via the Agent tool's `model`
  parameter.
