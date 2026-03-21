#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${REPO_SLUG:-jodok/dotfiles}"
BRANCH="${BRANCH:-main}"

curl -fsSL "https://raw.githubusercontent.com/${REPO_SLUG}/${BRANCH}/install.sh" | bash
