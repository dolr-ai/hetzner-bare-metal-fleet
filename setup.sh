#!/usr/bin/env bash
# Thin wrapper that delegates to `mise run setup`.
# All setup logic lives declaratively in mise.toml tasks.
#
# This script is OPTIONAL — if mise shell activation is installed (via `mise bootstrap`
# in ~/.dotfiles), entering this directory automatically runs the `bootstrap` task via
# the [hooks] enter hook in mise.toml. This script remains for explicit/manual setup.
#
# Prerequisites:
#   - mise installed (https://mise.jdx.dev/installing-mise.html)
#     Quick install:  curl https://mise.run | sh
#   - Shell activated:  eval "$(mise activate bash)"   (or zsh/fish)
set -euo pipefail
exec mise run setup
