#!/bin/bash
# Applique les suggestions MATRICE_A_RAFRAICHIR sur requirements_matrix.txt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIREMENTS_MATRIX="${REQUIREMENTS_MATRIX:-$SCRIPT_DIR/requirements_matrix.txt}"

RUN_DIR="${1:-}"
if [[ -z "$RUN_DIR" ]]; then
  LATEST="${LOG_BASE_DIR:-$HOME/Documents/AlphaLagoon/_logs_XcodeProjects/package_updater/audit}/latest"
  if [[ -L "$LATEST" ]]; then
    RUN_DIR="$(cd "$LATEST" && pwd)"
  else
    echo "Usage: $0 <audit_run_dir>"
    echo "  ou lancer un audit avant (lien audit/latest)."
    exit 1
  fi
fi

TSV="${RUN_DIR}/output/matrix_refresh.tsv"
if [[ ! -f "$TSV" ]]; then
  echo "ERREUR: $TSV introuvable. Lancez d'abord un audit."
  exit 1
fi

if [[ ! -f "$REQUIREMENTS_MATRIX" ]]; then
  echo "ERREUR: matrice introuvable: $REQUIREMENTS_MATRIX"
  exit 1
fi

BACKUP="${REQUIREMENTS_MATRIX}.bak.$(date +%Y%m%d_%H%M%S)"
cp "$REQUIREMENTS_MATRIX" "$BACKUP"
echo "Sauvegarde : $BACKUP"

export REQUIREMENTS_MATRIX TSV BACKUP
"$(
  command -v python3
)" <<'PY'
import os
import re
import sys
from pathlib import Path

matrix_path = Path(os.environ["REQUIREMENTS_MATRIX"])
tsv_path = Path(os.environ["TSV"])


def norm(v: str):
    v = v.lower().replace("-", ".")
    parts = []
    for token in re.split(r"[._+]", v):
        if token == "post":
            parts.append(0)
            continue
        m = re.match(r"^(\d+)", token)
        parts.append(int(m.group(1)) if m else 0)
    while len(parts) < 8:
        parts.append(0)
    return tuple(parts[:8])


# package -> max suggested floor (highest installed among MATRICE_A_RAFRAICHIR rows)
bumps: dict[str, str] = {}
for line in tsv_path.read_text(encoding="utf-8").splitlines():
    if not line.strip() or line.startswith("project\t"):
        continue
    parts = line.split("\t")
    if len(parts) < 5:
        continue
    pkg, installed, suggested = parts[1], parts[3], parts[4]
    if not installed or installed == "ABSENT":
        continue
    m = re.match(r"^(.+)>=(.+)$", suggested.strip())
    ver = m.group(2).strip() if m else installed.strip()
    key = m.group(1).strip() if m else pkg.strip()
    prev = bumps.get(key)
    if prev is None or norm(ver) > norm(prev):
        bumps[key] = ver

if not bumps:
    print("Aucune suggestion à appliquer (matrix_refresh.tsv vide).")
    sys.exit(0)


def pkg_from_spec(spec: str) -> str:
    return re.split(r"[<>=!~\[]", spec, maxsplit=1)[0].strip().lower().replace("_", "-")

def replace_min(spec: str, new_ver: str) -> str:
    m = re.match(r"^([A-Za-z0-9_.\-]+)\s*([<>=!~]+)\s*([A-Za-z0-9_.!\-+]+)", spec)
    if not m:
        return spec
    pkg, op, old = m.group(1), m.group(2), m.group(3)
    if norm(new_ver) <= norm(old):
        return spec
    return f"{pkg}{op}{new_ver}"

lines = matrix_path.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
changed = 0
for raw in lines:
    line = raw.rstrip("\n")
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "|" not in stripped:
        out.append(raw if raw.endswith("\n") else raw + "\n")
        continue
    spec_part = stripped.split("|", 1)[0].strip()
    rest = stripped.split("|", 1)[1]
    pkg = pkg_from_spec(spec_part)
    if pkg in bumps:
        new_spec = replace_min(spec_part, bumps[pkg])
        if new_spec != spec_part:
            changed += 1
            print(f"  {spec_part}  →  {new_spec}")
            out.append(f"{new_spec} | {rest}\n")
            continue
    out.append(raw if raw.endswith("\n") else raw + "\n")

matrix_path.write_text("".join(out), encoding="utf-8")
print(f"\n{changed} ligne(s) mise(s) à jour dans {matrix_path}")
PY

echo ""
echo "Relancez « Mettre à jour l'installateur » puis venv install si besoin."
