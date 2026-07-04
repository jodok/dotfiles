# Global agent rules

These rules apply to every repository and every coding agent. They are
installed machine-wide: Codex reads them via `~/.codex/AGENTS.md`, Claude
Code imports them from `~/.claude/CLAUDE.md`.

## Git and pull requests

- Never push directly to `main`.
- Work on a branch prefixed with the active agent name, for example
  `claude/...`, `codex/...`, or `tashi/...`.
- Use commitlint-compatible Conventional Commit messages.
- If a commit is not authored under Jodok's own identity (bot or cloud
  agents), add `Jodok Batlogg <jodok@batlogg.com>` as co-author.
- As soon as work is reviewable, commit it, push the branch, and open a
  pull request. Do not wait until the very end if review can happen earlier.
- After creating a pull request, send the exact clickable PR URL.
- Squash-merge into `main`.
- Repository-specific rules may add constraints, but must not weaken these
  global rules.

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
- If a task calls for a model above your own row (for example taste ≥ 7
  work while you run as gpt-5.5), say so and recommend handing it over
  instead of shipping below the bar.
