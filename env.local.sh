#!/usr/bin/env bash
set -euo pipefail

if [ -n "${BASH_SOURCE:-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  SCRIPT_PATH="${(%):-%N}"
else
  SCRIPT_PATH="$0"
fi

ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

source "$ROOT_DIR/.venv/bin/activate"
export LD_LIBRARY_PATH="$ROOT_DIR/.venv/lib:${LD_LIBRARY_PATH:-}"
