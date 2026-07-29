# Global agent rules

These rules apply to every repository and every coding agent. They are
installed machine-wide: Codex reads them via `~/.codex/AGENTS.md`, Claude
Code imports them from `~/.claude/CLAUDE.md`.

## Git and pull requests

- Author every commit as `Jodok Batlogg <jodok@batlogg.com>`. Agents and
  bots never take authorship; they credit themselves with a
  `Co-Authored-By:` trailer instead.
- `main` is protected: no direct pushes, no force pushes, linear history.
  Every change lands through a pull request.
- Branch names: `<agent>/<topic>` for agent work (`claude/...`,
  `codex/...`), `jodok/<topic>` for manual work.
- Use commitlint-compatible Conventional Commit messages. The PR title must
  be a valid Conventional Commit too — squash merging makes it the commit
  message on `main`.
- Open the PR as soon as the work is reviewable — as a draft if it is still
  in progress. After creating it, send the exact clickable PR URL.
- Codex auto-reviews every PR (ChatGPT Codex Connector). Address its
  findings and resolve all review threads before merging — branch
  protection enforces the resolution. Mention `@codex review` to re-request
  a review after larger follow-up pushes.
- Keep PRs small and single-topic; split unrelated changes.
- Squash-merge only, with required checks green; the branch is deleted on
  merge.
- **Merge your own PR yourself once everything is green** — required checks
  passed, review gate approved, every review thread resolved. Do not park a
  green PR waiting for Jodok to press the button, and do not ask whether to
  merge; green is the answer. Report the merge, do not announce the
  intention.
- Green means green as GitHub sees it: `mergeStateStatus` is `CLEAN` and no
  review thread is unresolved. A pending or failing check, a requested
  change, or an unresolved thread means fix it, not merge it — and never
  reach for an admin override to bypass a gate.
- Merge only what you opened. Someone else's PR, and anything whose scope
  Jodok is still deciding, stays for him.
- After merging, finish the chain: land the follow-ups that PR unblocked —
  version pins, dependent config — rather than leaving the change
  half-deployed.
- Force-pushing your own PR branch (for example after a rebase) is fine;
  never rewrite `main` or someone else's branch.
- Repository-specific rules may add constraints, but must not weaken these
  global rules.

## Picking the right models for workflows and subagents

Rankings, higher = better. Cost reflects what I actually pay — both OpenAI
and Claude (Max plan) are flat-rate subscriptions with generous limits, so
cost differences between Claude models reflect how fast each burns the Max
quota, not list price. Intelligence is how hard a problem you can hand the
model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model     | cost | intelligence | taste |
|-----------|------|--------------|-------|
| haiku-4.5 | 10   | 3            | 4     |
| gpt-5.5   | 9    | 8            | 5     |
| sonnet-5  | 9    | 5            | 7     |
| opus-4.8  | 7    | 8            | 8     |
| fable-5   | 5    | 9            | 9     |

How to apply:

- These are defaults, not limits. Standing permission to override them: if a
  cheaper model's output doesn't meet the bar, redo the work with a smarter
  model without asking. Judge the output, not the price tag — escalating
  costs less than shipping mediocre work.
- Cost is a tie-breaker only; when axes conflict for anything that ships,
  intelligence > taste > cost.
- Bulk/mechanical work (clear-spec implementation, data analysis,
  migrations): gpt-5.5 or sonnet-5, both effectively flat-rate. Prefer
  gpt-5.5 for token-heavy grinds (preserves Max quota), sonnet-5 when the
  output should read well.
- Unsupervised medium-hard chunks: opus-4.8 is a solid default now
  (intelligence 8 at cost 7), no longer a splurge.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans and implementations: fable-5 or opus-4.8, optionally
  gpt-5.5 as an extra independent perspective.
- haiku-4.5 is allowed for fully-specified mechanical sweeps where the
  spec determines the output (mass renames, file inventories, format
  checks, template boilerplate). Never for anything needing judgment.
- Supervisors (fable-5 especially) delegate DOWN by default: if a task is
  fully specified, hand it to the cheapest row that clears the bar — even
  when doing it inline feels faster. Small single-file fixes and doc edits
  are sonnet/haiku work. Inline fable work is reserved for architecture,
  ambiguous judgment, delegation specs, integration, review-of-reviews,
  and secret handling.
- If a task calls for a model above your own row (for example taste ≥ 7
  work while you run as gpt-5.5), say so and recommend handing it over
  instead of shipping below the bar.
