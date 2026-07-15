#!/usr/bin/env bash
# Thin wrapper that delegates to `mise run setup`.
# All setup logic lives declaratively in mise.toml tasks.
#
# Prerequisites:
#   - mise installed (https://mise.jdx.dev/installing-mise.html)
#     Quick install:  curl https://mise.run | sh
#   - Shell activated:  eval "$(mise activate bash)"   (or zsh/fish)
set -euo pipefail
exec mise run setup
