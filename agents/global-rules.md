<!-- Source of truth: jodok/dotfiles agents/global-rules.md — installed to
~/.agents/global-rules.md by install.sh. Edit the repo source, then deploy it;
do not edit only the installed copy. -->

# Global agent rules

These rules apply to every repository and every coding agent. They are
installed machine-wide: Codex reads them via `~/.codex/AGENTS.md`, Claude
Code imports them from `~/.claude/CLAUDE.md`.

Keep this file limited to reusable personal defaults. Repository architecture,
commands, lifecycle, review gates, and deployment policy belong in that
repository's `AGENTS.md`.

## Git and pull requests

- Author every commit as `Jodok Batlogg <jodok@batlogg.com>`. Agents and
  bots never take authorship; they credit themselves with a
  `Co-Authored-By:` trailer instead.
- **Agents sign and push with their own keys, from 1Password, through their own
  agent.** The installer sets `env.GIT_CONFIG_GLOBAL` for Claude Code sessions, so
  git already uses it — nothing to pass by hand. Do **not** force that variable
  when it is absent: the installer deliberately leaves it unset until both keys are
  provisioned, and the config it names sets `commit.gpgsign` with a signing key that
  would not exist, so forcing it turns a skipped 1Password step into a git that
  cannot commit. If `~/.claude/claude-signing.pub` is missing, provisioning was
  skipped — run `op signin` and `install.sh` again rather than working around it.
  What the setup gives you: commits are signed by `claude-signing`, pushes authenticate
  as `claude-auth`, both held in 1Password and loaded into a plain `ssh-agent`
  at `~/.claude/run/agent.sock` by `~/.claude/bin/claude-ssh-agent`. No private
  key is written to disk — `op read` streams each one into `ssh-add -` — there
  are no approval prompts, and it does not depend on the 1Password desktop
  agent, which prompts and fails intermittently. The identity is separate, so it
  can be revoked on GitHub without touching Jodok's own keys.
  - Re-run `~/.claude/bin/claude-ssh-agent` if the socket is missing; it is
    idempotent and reloads only when a key is absent. It needs `op` signed in.
  - Four things this rests on, each of which cost a debugging round. `op read`
    must use `?ssh-format=openssh`, because the default field is PKCS#8 and
    `ssh-add` rejects it, and the output needs a trailing newline appended.
    `~/.claude/ssh_config` is git's own and deliberately does not include
    `~/.ssh/config`: including it let an ssh alias whose `HostName` is
    `github.com` supply a personal key and push as the human account, and there
    is no way to inherit routing without inheriting identities. So an ssh alias
    means nothing to agent git — add the host block to that file instead. Signing runs `ssh-keygen`,
    which takes its agent from `SSH_AUTH_SOCK` and not from `core.sshCommand`,
    so `gpg.ssh.program` points at a shim that pins the socket; without it
    commits fail with `Couldn't find key in agent?`. And `gpg.ssh.allowedSignersFile`
    must list `<principal> <keytype> <key>` — omit the key type and verification
    fails while signing still appears to work.
- `main` is protected: no direct pushes, no force pushes, linear history.
  Every change lands through a pull request.
- Branch names: `<agent>/<topic>` for agent work (`claude/...`,
  `codex/...`), `jodok/<topic>` for manual work.
- Use commitlint-compatible Conventional Commit messages. The PR title must
  be a valid Conventional Commit too — squash merging makes it the commit
  message on `main`.
- Open the PR as soon as the work is reviewable — as a draft if it is still
  in progress. After creating it, send the exact clickable PR URL.
- Follow the repository's review policy. A reviewer error or missing result is
  neither a finding nor an approval; do not merge until the repository's real
  review gate is satisfied.
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

## Picking the right models for workflows and subagents

Rankings, higher = better. Cost is an availability score, not API list
price. There is one high-capacity subscription with each provider, but as of
2026-09-01 OpenAI plan headroom (Codex, including GPT Sol) is plentiful — when
a task fits both providers' rows equally, delegate it to Codex and keep
Anthropic quota for supervision, review, and taste-critical surfaces.
Codex-Spark has an additional, separate quota lane. Cost differences within a
provider reflect how quickly each model burns its plan quota. Intelligence is
how hard a problem you can hand the model unsupervised. Taste covers UI/UX,
code quality, API design, and copy.

| model                 | cost | intelligence | taste |
|-----------------------|------|--------------|-------|
| gpt-5.3-codex-spark   | 10   | 4            | 4     |
| gpt-5.5               | 9    | 8            | 5     |
| haiku-4.5             | 10   | 3            | 4     |
| sonnet-5              | 9    | 5            | 7     |
| opus-4.8              | 7    | 8            | 8     |
| fable-5               | 5    | 9            | 9     |

GPT Sol is newly available on the Codex quota lane and not yet scored here —
until it earns its own row, treat it like gpt-5.5 and score it after a few
real tasks.

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
  sonnet-5 when the output needs its stronger taste. When the two tie,
  current Codex headroom breaks the tie toward gpt-5.5.
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
