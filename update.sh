#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${REPO_SLUG:-jodok/dotfiles}"
BRANCH="${BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_SLUG}/${BRANCH}"

curl -fsSL "$RAW_BASE/install.sh" | bash
