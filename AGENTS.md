# AGENTS.md

Global agent rules live in [agents/global-rules.md](agents/global-rules.md)
and are installed machine-wide by `install.sh` (Codex loads them via
`~/.codex/AGENTS.md`, Claude Code via an import in `~/.claude/CLAUDE.md`).
Do not duplicate them here.

## Repository specific rules

- Keep this repository focused on shell and terminal environment setup.
- Keep the installer idempotent.
- Prefer safe patching over destructive replacement of user files.
- Avoid background daemons unless explicitly requested.
- If install or update behavior changes, update the README in the same PR.
- `agents/global-rules.md` and `agents/claude.md` are the source of truth
  for `~/.agents/global-rules.md` and `~/.claude/CLAUDE.md`. Edit them here
  and reinstall; never edit only the installed copies.
