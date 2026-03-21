# AGENTS.md

This file applies to the `jodok/dotfiles` repository.

It combines:
- the global rules that should apply to all repositories
- the repository-specific rules for `jodok/dotfiles`

Keep those two layers cleanly separated.
If a rule is general across repositories, it belongs in `jodok/agents` and should bubble down here.
If a rule is specific to dotfiles, it belongs here and should stay local unless it later proves generally useful.
If a local rule turns out to be broadly applicable, bubble it up into `jodok/agents` first, then propagate it back down into repositories.

## Global rules inherited for all repositories

These rules come from `jodok/agents` and must be kept aligned with that repository.

### Git and branch workflow

- Never push directly to `main`.
- Always work on a branch prefixed with the active agent name, for example `tashi/...`, `codex/...`, or `claude/...`.
- Keep branches focused and scoped to one task or change set.

### Commits

- Always create commitlint-compatible commit messages using Conventional Commits.
- Always add `Jodok Batlogg <jodok@batlogg.com>` as co-author on commits.
- Commit work when a meaningful unit is complete. Do not leave finished work uncommitted.

### Pull requests

- When work is complete, always commit, push, and open a pull request.
- Keep pull requests reviewable and clearly scoped.
- Mention relevant checks or tests in the PR description. If checks were not run, say so explicitly.

### Merging

- Never merge directly into `main` by pushing.
- When merging to `main`, always squash-merge.

## Dotfiles-specific rules

### Scope

- Keep this repository focused on shell and terminal environment setup.
- Do not mix unrelated repository-governance or product-specific coding rules into this repository.
- Keep the payload small and pragmatic.

### Installer behavior

- Keep the installer idempotent.
- Prefer safe patching over destructive replacement of user files.
- Avoid background daemons for updates unless explicitly requested.
- Prefer standard oh-my-zsh locations and behavior over custom framework-like layering.

### Repository changes

- Prefer minimal changes that improve portability, clarity, or reliability.
- Keep README examples aligned with the current install flow.
- If the install or update behavior changes, update the documentation in the same PR.

## Bubble-down workflow from global to local

When `jodok/agents` changes globally:

1. Update the global section in this file to match.
2. Preserve the dotfiles-specific section.
3. Commit, push, and open a PR in this repository.
4. Squash-merge after review.

## Bubble-up workflow from local to global

When working in this repository reveals a new rule that should apply to all repositories:

1. Add or propose that rule in `jodok/agents` first.
2. Merge it there.
3. Then sync the updated global rule back into this file.

Do not keep cross-repository policy only in this repository.
