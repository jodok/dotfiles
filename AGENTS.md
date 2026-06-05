# AGENTS.md

## Repository specific rules

- Keep this repository focused on shell and terminal environment setup.
- Keep the installer idempotent.
- Prefer safe patching over destructive replacement of user files.
- Avoid background daemons unless explicitly requested.
- If install or update behavior changes, update the README in the same PR.
- If a rule discovered here should apply to all repositories, move it up to `jodok/agents` first.

## Global rules

- Never push directly to `main`.
- Always work on a branch prefixed with the active agent name, for example `tashi/...`, `codex/...`, or `claude/...`.
- Always use commitlint-compatible Conventional Commit messages.
- Always add `Jodok Batlogg <jodok@batlogg.com>` as co-author on commits.
- As soon as work is reviewable, always commit it, push the branch, and open a pull request. Do not wait until the very end if review can happen earlier.
- After creating a pull request, always send the user the exact clickable PR URL.
- Always squash-merge into `main`.
- Repository-specific rules may add constraints, but must not weaken these global rules.
- Every repository using these global rules must have a root `AGENTS.md` that includes them.
- If a rule should apply across repositories, add it here first and then update the consuming repositories.
