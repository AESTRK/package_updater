#!/bin/bash
# Audit installed packages in project .venv vs requirements matrix.
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/PycharmProjects}"
LOG_BASE_DIR="${LOG_BASE_DIR:-$HOME/Documents/AlphaLagoon/_logs/package_audit}"
REQUIREMENTS_MATRIX="${REQUIREMENTS_MATRIX:-$SCRIPT_DIR/requirements_matrix.txt}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

RUN_TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${LOG_BASE_DIR}/${RUN_TS}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/run.log"
PACKAGE_CHECK_FILE="${LOG_DIR}/package_check.txt"

exec > >(tee -a "$LOG_FILE") 2>&1

log() { printf '%s\n' "$*"; }
log_ok() { printf "${GREEN}%s${NC}\n" "$*"; }
log_warn() { printf "${YELLOW}%s${NC}\n" "$*"; }
log_err() { printf "${RED}%s${NC}\n" "$*"; }

matrix_package_name() {
  local spec="$1"
  spec="${spec%%[*]}"
  spec="${spec%%[<>=!~]*}"
  spec="${spec%%;*}"
  spec="$(echo "$spec" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
  printf '%s\n' "$spec"
}

version_ge() {
  python3 - "$1" "$2" <<'PYCMP'
import sys
def parse(v):
    parts = []
    for x in v.strip().split('.'):
        num = ''
        for ch in x:
            if ch.isdigit():
                num += ch
            else:
                break
        parts.append(int(num) if num else 0)
    return parts
a, b = parse(sys.argv[1]), parse(sys.argv[2])
n = max(len(a), len(b))
a += [0] * (n - len(a))
b += [0] * (n - len(b))
sys.exit(0 if a >= b else 1)
PYCMP
}

pip_show_version() {
  local venv_pip="$1" pkg="$2"
  "$venv_pip" show "$pkg" 2>/dev/null | awk -F': ' '/^Version:/{print $2; exit}'
}

pip_index_latest() {
  local venv_pip="$1" pkg="$2"
  "$venv_pip" index versions "$pkg" 2>/dev/null | head -n1 | sed -n 's/.*(\(.*\)).*/\1/p'
}

matrix_min_version() {
  local spec="$1"
  if [[ "$spec" == *">="* ]]; then
    printf '%s\n' "${spec#*>=}"
  elif [[ "$spec" == *"=="* ]]; then
    printf '%s\n' "${spec#*==}"
  else
    printf '%s\n' "-"
  fi
}

run_audit_pass() {
  printf 'project\tpackage\texpected\tinstalled\tindex_latest\tstatus\n' >"$PACKAGE_CHECK_FILE"
  local line spec projects part proj_dir venv_pip pkg expected installed latest status minv
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue
    [[ "$line" != *"|"* ]] && continue
    spec="${line%%|*}"
    spec="$(echo "$spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    projects="${line#*|}"
    projects="$(echo "$projects" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    IFS=',' read -ra _projs <<< "$projects"
    for part in "${_projs[@]}"; do
      part="$(echo "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ -z "$part" ]] && continue
      [[ "$part" == "ALL" || "$part" == "all" ]] && continue
      proj_dir="$PROJECTS_ROOT/$part"
      [[ -x "$proj_dir/.venv/bin/pip" ]] || continue
      venv_pip="$proj_dir/.venv/bin/pip"
      pkg="$(matrix_package_name "$spec")"
      expected="$spec"
      minv="$(matrix_min_version "$spec")"
      installed="$(pip_show_version "$venv_pip" "$pkg")"
      installed="${installed:-missing}"
      latest="$(pip_index_latest "$venv_pip" "$pkg")"
      latest="${latest:-}"
      status="ok"
      if [[ "$installed" == "missing" ]]; then
        status="missing"
      elif [[ "$minv" != "-" ]] && ! version_ge "$installed" "$minv"; then
        status="below_min"
      fi
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$part" "$pkg" "$expected" "$installed" "$latest" "$status" >>"$PACKAGE_CHECK_FILE"
    done
  done <"$REQUIREMENTS_MATRIX"
  log "Package audit written: $PACKAGE_CHECK_FILE"
}

main() {
  if [[ ! -f "$REQUIREMENTS_MATRIX" ]]; then
    log_err "Matrix missing: $REQUIREMENTS_MATRIX"
    exit 1
  fi
  log "Audit | Projects: $PROJECTS_ROOT | Log: $LOG_DIR"
  log "Matrix: $REQUIREMENTS_MATRIX"
  run_audit_pass
  log_ok "Audit terminé."
}

main "$@"
