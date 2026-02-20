# syntax=docker/dockerfile:1.7

ARG MLIR_BASE_IMAGE=ghcr.io/sdiehl/docker-mlir-cuda:mlir19-ubuntu24.04
FROM ${MLIR_BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG PET_REPO=https://github.com/zhen8838/pet.git

ENV VENV=/opt/venv \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    bison \
    build-essential \
    ca-certificates \
    clang-14 \
    cmake \
    flex \
    git \
    graphviz \
    libclang-14-dev \
    libgmp-dev \
    libopenmpi-dev \
    libtool \
    libyaml-dev \
    llvm-14-dev \
    llvm-14-tools \
    m4 \
    ninja-build \
    openmpi-bin \
    pkg-config \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv --system-site-packages "${VENV}"
ENV PATH="${VENV}/bin:${PATH}"

RUN python -m pip install --upgrade pip setuptools wheel \
 && python -m pip install \
    graphviz \
    ipykernel \
    isl-python \
    jupyterlab \
    matplotlib \
    more-itertools \
    mpi4py \
    nbconvert \
    notebook \
    numpy \
    pandas \
    pybind11==2.11.2 \
    xdsl==0.48.3 \
 && python -m pip install git+https://github.com/gaogaotiantian/dowhen.git

# Ensure the chosen public MLIR image really exposes the Python API expected by notebooks.
RUN python - <<'PY'
from mlir.ir import AffineMapAttr
from mlir.dialects.affine import AffineForOp, AffineIfOp, AffineLoadOp, AffineStoreOp
assert hasattr(AffineMapAttr, "value"), (
    "Selected base image does not expose AffineMapAttr.value. "
    "Pick a newer MLIR image or override MLIR_BASE_IMAGE."
)
print("MLIR Python API check: OK", AffineForOp, AffineIfOp, AffineLoadOp, AffineStoreOp)
PY

RUN git clone --recursive "${PET_REPO}" /opt/pet \
 && cd /opt/pet \
 && if [ ! -f gitversion.h ]; then printf '#define GIT_HEAD_ID "%s"\n' "$(git rev-parse --short HEAD || echo unknown)" > gitversion.h; fi \
 && if [ ! -f isl/gitversion.h ]; then printf '#define GIT_HEAD_ID "%s"\n' "$(cat isl/GIT_HEAD_ID 2>/dev/null || echo unknown)" > isl/gitversion.h; fi \
 && ./configure --prefix=/opt/pet/build --with-clang-prefix=/usr/lib/llvm-14 \
 && make -j"$(nproc)" -C isl interface/extract_interface \
 && make -j"$(nproc)" isl.py \
 && make -j"$(nproc)" pet \
 && make -j"$(nproc)" libpet.la

# Patch generated bindings for Linux libc discovery and safer printer behavior.
RUN python - <<'PY'
from pathlib import Path

p = Path("/opt/pet/isl.py")
s = p.read_text()

if "from ctypes.util import find_library" not in s:
    s = s.replace(
        "from ctypes import *\n",
        "from ctypes import *\nfrom ctypes.util import find_library\n",
        1,
    )

needle = 'libc = cdll.LoadLibrary("libc" + get_lib_ext())'
replacement = (
    '_libc_name = find_library("c") or ("libc.so.6" if platform.system() == "Linux" '
    'else "libc" + get_lib_ext())\n'
    "libc = cdll.LoadLibrary(_libc_name)"
)
if needle in s:
    s = s.replace(needle, replacement, 1)

tail = """
# Work around crashes in isl_ast_node_print on some Linux builds by
# rendering nodes through to_C_str() and writing that text to the printer.
def _safe_ast_node_print(node, p, opt):
    try:
        if not p.__class__ is printer:
            p = printer(p)
    except:
        raise
    _ = opt
    return p.print_str(node.to_C_str())

for _cls in [ast_node, ast_node_block, ast_node_for, ast_node_if, ast_node_mark, ast_node_user]:
    _cls.print = _safe_ast_node_print

# printer/context lifetime management in this generated binding can trigger
# double-free and late free warnings; use process-lifetime cleanup.
def _noop_destructor(self):
    _ = self
    return None

printer.__del__ = _noop_destructor
Context.__del__ = _noop_destructor

def _safe_printer_print_schedule(p, s):
    try:
        if not p.__class__ is printer:
            p = printer(p)
    except:
        raise
    try:
        if not s.__class__ is schedule:
            s = schedule(s)
    except:
        raise
    return p.print_str(str(s))

def _safe_printer_print_ast_node(p, n):
    try:
        if not p.__class__ is printer:
            p = printer(p)
    except:
        raise
    try:
        if not n.__class__ is ast_node:
            n = ast_node(n)
    except:
        raise
    return p.print_str(n.to_C_str())

printer.print_schedule = _safe_printer_print_schedule
printer.print_ast_node = _safe_printer_print_ast_node
"""
if "_safe_ast_node_print" not in s:
    s = s.rstrip() + "\n\n" + tail.lstrip()

p.write_text(s)
print("Patched", p)
PY

RUN python - <<'PY'
import json
from pathlib import Path

base = Path("/opt/venv/share/jupyter/kernels")
base.mkdir(parents=True, exist_ok=True)

py312 = {
    "argv": ["/opt/venv/bin/python", "-m", "ipykernel_launcher", "-f", "{connection_file}"],
    "display_name": "handson-polyhedral (py312)",
    "language": "python",
    "metadata": {"debugger": True},
    "env": {
        "LD_LIBRARY_PATH": "/opt/venv/lib:${LD_LIBRARY_PATH}"
    },
}

py312_pet = {
    "argv": ["/opt/venv/bin/python", "-m", "ipykernel_launcher", "-f", "{connection_file}"],
    "display_name": "handson-polyhedral (py312+pet)",
    "language": "python",
    "metadata": {"debugger": True},
    "env": {
        "PYTHONPATH": "/opt/pet/interface:/opt/pet:${PYTHONPATH}",
        "LD_LIBRARY_PATH": "/opt/pet/.libs:/opt/pet/isl/.libs:/opt/venv/lib:${LD_LIBRARY_PATH}",
    },
}

for name, spec in {
    "handson-polyhedral-py312": py312,
    "handson-polyhedral-py312-pet": py312_pet,
}.items():
    d = base / name
    d.mkdir(parents=True, exist_ok=True)
    (d / "kernel.json").write_text(json.dumps(spec, indent=1))
PY

WORKDIR /workspace/handson-polyhedral
COPY . /workspace/handson-polyhedral

ENV JUPYTER_CONFIG_DIR=/workspace/.jupyter \
    JUPYTER_DATA_DIR=/workspace/.jupyter \
    JUPYTER_RUNTIME_DIR=/workspace/.jupyter/runtime \
    JUPYTER_PATH=/opt/venv/share/jupyter

RUN mkdir -p "${JUPYTER_RUNTIME_DIR}"

EXPOSE 8888
CMD ["bash"]
