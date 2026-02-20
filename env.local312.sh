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

source "$ROOT_DIR/.venv312/bin/activate"
MLIR_PY_ROOT="$ROOT_DIR/llvm-build-17/tools/mlir/python_packages/mlir_core"

if [ -d "$MLIR_PY_ROOT" ]; then
  export PYTHONPATH="$MLIR_PY_ROOT:${PYTHONPATH:-}"
fi
export LD_LIBRARY_PATH="$ROOT_DIR/.venv312/lib:${LD_LIBRARY_PATH:-}"
