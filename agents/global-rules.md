<!-- Source of truth: jodok/dotfiles agents/global-rules.md — installed to
~/.agents/global-rules.md by install.sh. Edit the repo source, then deploy it;
do not edit only the installed copy. -->

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
- Squash-merge only, with required checks green.
- **Delete the branch when it merges.** Pass `--delete-branch` to
  `gh pr merge` every time rather than trusting it to happen by itself, and
  remove the local branch and any worktree too. A squash-merged branch
  reports itself as "ahead of main" forever, so leftovers read as unfinished
  work months later and cost someone a real investigation. Squash-merging is
  also why `git branch -d` refuses and `--merged` never lists these: the
  branch tip is not an ancestor of `main`. The check that tells the truth is
  an empty `git diff origin/main <branch>`, and `-D` is what deletes. A
  worktree pins its branch, so `git worktree remove` has to come first.
- **Repositories must set `delete_branch_on_merge`.** Check it with
  `gh api repos/<owner>/<repo> --jq .delete_branch_on_merge`; if it is
  `false`, turn it on with
  `gh api -X PATCH repos/<owner>/<repo> -F delete_branch_on_merge=true`.
  The repo setting is the safety net for merges made outside the CLI — the
  web UI's merge button honors it — so both belong in place, not one or the
  other. It is a per-repository flag with no org-wide default, so a new repo
  starts `false`: when you check it, check every repo in the org, not only the
  one you are working in.
- **Sweeping stale branches is a whole-org job.** A branch is safe to delete
  only when its pull request is `MERGED`. Leave `OPEN` ones alone; leave
  `CLOSED`-without-merge alone, because that work never landed; and leave
  branches with no pull request at all alone, because their provenance is
  unknown. Skip vendored forks of other people's projects entirely — their
  branches are not ours to judge.
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

## Deployment flows

Two flows exist. Which one applies is a property of the repo, not of the PR
— check the Flow B list below before assuming Flow A.

- **Flow A — bot-reviewed (default).** Applies to every repo not listed
  under Flow B. Branch, push, open the PR ready (not draft). namche-review
  picks it up automatically; iterate until it is green and every thread is
  resolved, then squash-merge. The repo's own pipeline deploys from there —
  staging automatically, production per that repo's own rules.
  - **When the reviewer is unavailable** (disabled, as it is since
    2026-08-26, or erroring), Flow A does not become "merge unreviewed" and
    it does not become "wait indefinitely". Run the `/code-review` skill
    locally and post its findings as a PR comment naming the reviewed head
    SHA — the Flow B convention — and gate the merge on CI plus resolved
    threads. A reviewer-infrastructure diagnostic ("no result for this
    generation", `executor_error`) is explicitly not a finding and not an
    approval; never read one as either.
- **Flow B — local review + staging-first.** Currently: `NamcheAI/sirdar`.
  More repos opt in by being listed here, not by resembling sirdar.
  - Branch or worktree, push as needed, and open the PR early — draft is
    fine. The PR is the review trail, so it has to exist before the work is
    done, not after.
  - Test locally. When review is wanted, run the `/code-review` skill
    locally at high effort and post its findings as a PR comment that names
    the reviewed head SHA. Address findings, iterate. namche-review does not
    run on these repos — there is no bot to wait for.
  - Staging is a pre-merge iteration tool, not a deploy step: `just stage`
    (the repo's justfile) builds an amd64 image from a clean worktree,
    pushes it, and dispatches the infra-owned deploy interface for
    `environment=staging`. The app repo never names hosts —
    NamcheAI/infra's committed map owns app×env→host. Every staging deploy
    posts a PR comment saying what staging now runs; staging is single-slot,
    so the last writer wins.
  - Marking the PR ready triggers CI. The `check` job is the required gate,
    plus review-thread resolution, same bar as Flow A. Squash-merge on
    green.
  - Merging to main rebuilds the image from the merge commit and deploys
    production automatically, then re-syncs staging to main. Production
    never runs a locally-built image — the staging build above is for
    iteration, not for shipping.
  - Flow B repos standardise local verbs in a `justfile`; `just --list` is
    the discovery surface (`dev`, `test`, `typecheck`, `stage`, `review`).
  - Variations (no staging, one-line fixes) may skip the staging step; the
    review-findings-on-PR convention still holds.

## Picking the right models for workflows and subagents

Rankings, higher = better. Cost is an availability score, not API list
price. There is one high-capacity subscription with each provider, so treat
OpenAI and Anthropic plan headroom as broadly balanced. Codex-Spark has an
additional, separate quota lane. Cost differences within a provider reflect
how quickly each model burns its plan quota. Intelligence is how hard a
problem you can hand the model unsupervised. Taste covers UI/UX, code quality,
API design, and copy.

| model                 | cost | intelligence | taste |
|-----------------------|------|--------------|-------|
| gpt-5.3-codex-spark   | 10   | 4            | 4     |
| gpt-5.5               | 9    | 8            | 5     |
| haiku-4.5             | 10   | 3            | 4     |
| sonnet-5              | 9    | 5            | 7     |
| opus-4.8              | 7    | 8            | 8     |
| fable-5               | 5    | 9            | 9     |

How to apply:

- These are defaults, not limits. Standing permission to override them: if a
  cheaper model's output doesn't meet the bar, redo the work with a smarter
  model without asking. Judge the output, not the price tag — escalating
  costs less than shipping mediocre work.
- Cost is a tie-breaker only; when axes conflict for anything that ships,
  intelligence > taste > cost.
- Use gpt-5.3-codex-spark first for narrow, well-specified work whose result
  is quick to review: exact UI adjustments, localized fixes, straightforward
  tests, boilerplate, mechanical refactors, and quick repository questions.
  It is the fastest Codex model and draws from a separate quota, but is
  text-only and less capable. Do not use it for architecture, ambiguous
  debugging, security work, complex migrations, unfamiliar cross-cutting
  changes, or judgment-heavy UI/copy. Treat it as opportunistic research-
  preview capacity; workflows must not depend on its continued availability.
- Bulk/mechanical work (clear-spec implementation, data analysis,
  migrations): prefer gpt-5.5 when its higher intelligence helps; use
  sonnet-5 when the output needs its stronger taste. Provider headroom is no
  longer the deciding factor between them.
- Unsupervised medium-hard chunks: opus-4.8 is a solid default when its
  intelligence and taste justify its higher quota burn (intelligence 8 at
  cost 7).
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans and implementations: fable-5 or opus-4.8, optionally
  gpt-5.5 as an extra independent perspective.
- haiku-4.5 is allowed for fully-specified mechanical sweeps where the
  spec determines the output (mass renames, file inventories, format
  checks, template boilerplate). Never for anything needing judgment.
- Supervisors (fable-5 especially) delegate DOWN by default: if a task is
  fully specified, hand it to the cheapest row that clears the bar — even
  when doing it inline feels faster. Fully specified single-file fixes and
  doc edits are Spark/haiku work; use sonnet when taste matters. Inline fable
  work is reserved for architecture, ambiguous judgment, delegation specs,
  integration, review-of-reviews, and secret handling.
- If a task calls for a model above your own row (for example taste ≥ 7
  work while you run as gpt-5.5), say so and recommend handing it over
  instead of shipping below the bar.
