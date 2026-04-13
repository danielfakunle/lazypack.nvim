#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DEPS_DIR="$ROOT_DIR/.deps"
PLENARY_DIR="$DEPS_DIR/plenary.nvim"

mkdir -p "$DEPS_DIR"

if [ ! -d "$PLENARY_DIR/.git" ]; then
  git clone --depth=1 https://github.com/nvim-lua/plenary.nvim.git "$PLENARY_DIR"
fi

nvim --headless -u "$ROOT_DIR/tests/minimal_init.lua" \
  -c "PlenaryBustedDirectory $ROOT_DIR/tests { minimal_init = '$ROOT_DIR/tests/minimal_init.lua' }" \
  -c "qa"
