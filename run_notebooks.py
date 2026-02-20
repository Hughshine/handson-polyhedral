#!/usr/bin/env python3
import argparse
import json
import re
import time
from pathlib import Path

import nbformat
from nbclient import NotebookClient


def pick_kernel(notebook_name: str) -> str:
    m = re.match(r"^(\d+)", notebook_name)
    idx = int(m.group(1)) if m else -1
    if 8 <= idx <= 11:
        return "handson-polyhedral-py312-pet"
    return "handson-polyhedral-py312"


def main() -> int:
    parser = argparse.ArgumentParser(description="Execute all notebooks and record pass/fail.")
    parser.add_argument("--root", default=".", help="Notebook root directory.")
    parser.add_argument(
        "--output",
        default=".nbtest_logs/results.jsonl",
        help="Path to jsonl result file.",
    )
    parser.add_argument("--timeout", type=int, default=600, help="Cell timeout in seconds.")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    notebooks = sorted(root.glob("*.ipynb"))
    out = (root / args.output).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("", encoding="utf-8")

    print(f"TOTAL_NOTEBOOKS={len(notebooks)}")
    for i, nb_path in enumerate(notebooks, 1):
        kernel = pick_kernel(nb_path.name)
        t0 = time.time()
        rec = {
            "notebook": nb_path.name,
            "kernel": kernel,
            "status": "ok",
            "seconds": None,
            "error_type": None,
            "error": None,
        }
        print(f"[{i}/{len(notebooks)}] START {nb_path.name} kernel={kernel}", flush=True)
        try:
            nb = nbformat.read(nb_path, as_version=4)
            client = NotebookClient(
                nb,
                timeout=args.timeout,
                kernel_name=kernel,
                resources={"metadata": {"path": str(root)}},
                allow_errors=False,
            )
            client.execute()
            print(f"[{i}/{len(notebooks)}] PASS {nb_path.name}", flush=True)
        except Exception as exc:
            rec["status"] = "fail"
            rec["error_type"] = type(exc).__name__
            rec["error"] = str(exc)
            print(
                f"[{i}/{len(notebooks)}] FAIL {nb_path.name} :: {type(exc).__name__}: {exc}",
                flush=True,
            )
        rec["seconds"] = round(time.time() - t0, 2)
        with out.open("a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    print(f"DONE results={out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
