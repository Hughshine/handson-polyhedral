#!/usr/bin/env bash
set -euo pipefail

if [ -n "${BASH_SOURCE:-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  SCRIPT_PATH="${(%):-%N}"
else
  SCRIPT_PATH="$0"
fi

ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
PY_DIR="$ROOT_DIR/.python312"
VENV_DIR="$ROOT_DIR/.venv312"
PY_BIN="$PY_DIR/bin/python3.12"

PY_STANDALONE_URL="${PY_STANDALONE_URL:-https://github.com/astral-sh/python-build-standalone/releases/download/20260211/cpython-3.12.12+20260211-x86_64-unknown-linux-gnu-install_only.tar.gz}"

echo "[1/4] Install local Python 3.12 to $PY_DIR"
if [ ! -x "$PY_BIN" ]; then
  mkdir -p "$PY_DIR"
  tmp_tar="$(mktemp /tmp/python312-standalone-XXXXXX.tar.gz)"
  curl -fL "$PY_STANDALONE_URL" -o "$tmp_tar"
  tar -xzf "$tmp_tar" -C "$PY_DIR" --strip-components=1
  rm -f "$tmp_tar"
else
  echo "Python 3.12 already exists, skip download."
fi

echo "[2/4] Create virtualenv $VENV_DIR"
if [ ! -x "$VENV_DIR/bin/python" ]; then
  "$PY_BIN" -m venv "$VENV_DIR"
else
  echo "Virtualenv already exists, skip create."
fi

echo "[3/4] Install Python packages"
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip setuptools wheel
python -m pip install \
  jupyterlab ipykernel numpy pandas matplotlib \
  isl-python xdsl==0.48.3 mpi4py more-itertools
python -m pip install git+https://github.com/gaogaotiantian/dowhen.git

echo "[4/4] Register kernels with runtime env"
python - <<PY
import json
from pathlib import Path

root = Path("${ROOT_DIR}")
venv = Path("${VENV_DIR}")
kernel_root = venv / "share" / "jupyter" / "kernels"
kernel_root.mkdir(parents=True, exist_ok=True)

common_env = {
    "LD_LIBRARY_PATH": f"{venv}/lib:${{LD_LIBRARY_PATH}}",
    "PYTHONPATH": f"{root}/llvm-build-17/tools/mlir/python_packages/mlir_core:${{PYTHONPATH}}",
}

for name, display, extra_env in [
    ("handson-polyhedral-py312", "handson-polyhedral (py312)", {}),
    (
        "handson-polyhedral-py312-pet",
        "handson-polyhedral (py312+pet)",
        {
            "PYTHONPATH": f"{root}/pet/interface:{root}/pet:{root}/llvm-build-17/tools/mlir/python_packages/mlir_core:${{PYTHONPATH}}",
            "LD_LIBRARY_PATH": f"{root}/pet/.libs:{root}/pet/isl/.libs:{venv}/lib:${{LD_LIBRARY_PATH}}",
        },
    ),
]:
    d = kernel_root / name
    d.mkdir(parents=True, exist_ok=True)
    spec = {
        "argv": [str(venv / "bin" / "python"), "-m", "ipykernel_launcher", "-f", "{connection_file}"],
        "display_name": display,
        "language": "python",
        "metadata": {"debugger": True},
        "env": common_env | extra_env,
    }
    (d / "kernel.json").write_text(json.dumps(spec, indent=1), encoding="utf-8")

# Also patch default python3 kernel if present so VSCode selecting it still works.
py3 = kernel_root / "python3" / "kernel.json"
if py3.exists():
    data = json.loads(py3.read_text(encoding="utf-8"))
    data["argv"][0] = str(venv / "bin" / "python")
    env = data.get("env", {})
    env.update(common_env)
    data["env"] = env
    py3.write_text(json.dumps(data, indent=1), encoding="utf-8")
PY

echo
echo "Done."
echo "Use:"
echo "  source \"$ROOT_DIR/env.local312.sh\""
