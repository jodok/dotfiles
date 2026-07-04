# Global agent rules

These rules apply to every repository. They are installed machine-wide:
Codex reads them via `~/.codex/AGENTS.md`, Claude Code imports them from
`~/.claude/CLAUDE.md`.

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
