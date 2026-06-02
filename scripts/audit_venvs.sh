#!/bin/bash
# Audit des .venv vs matrice — rapport coloré + dossier output/.
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/PycharmProjects}"
LOG_BASE_DIR="${LOG_BASE_DIR:-$HOME/Documents/AlphaLagoon/_logs_XcodeProjects/package_updater/audit}"
REQUIREMENTS_MATRIX="${REQUIREMENTS_MATRIX:-$SCRIPT_DIR/requirements_matrix.txt}"

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
BOLD=$'\033[1m'
RESET=$'\033[0m'
NC="$RESET"

RUN_TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${LOG_BASE_DIR}/${RUN_TS}"
OUTPUT_DIR="${LOG_DIR}/output"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="${LOG_DIR}/run.log"
PACKAGE_CHECK_FILE="${OUTPUT_DIR}/package_check.txt"
MATRIX_CHECK_FILE="${OUTPUT_DIR}/matrix_check.txt"
MATRIX_REFRESH_TSV="${OUTPUT_DIR}/matrix_refresh.tsv"
SUMMARY_FILE="${OUTPUT_DIR}/summary.txt"
PATHS_FILE="${OUTPUT_DIR}/paths.txt"
PROJECT_RECORDS="${LOG_DIR}/.project_records.tsv"

print_line() { printf '%*s\n' 78 '' | tr ' ' '='; }
print_section() { echo ""; print_line; echo "$1"; print_line; }

log_ok() { printf "${GREEN}%s${NC}\n" "$*"; }
log_warn() { printf "${YELLOW}%s${NC}\n" "$*"; }
log_err() { printf "${RED}%s${NC}\n" "$*"; }

resolve_python() {
  local c
  for c in /opt/homebrew/bin/python3.14 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
    [[ -x "$c" ]] && { echo "$c"; return 0; }
  done
  command -v python3
}

PYTHON_BIN="$(resolve_python)"
if [[ -z "$PYTHON_BIN" || ! -x "$PYTHON_BIN" ]]; then
  echo "ERREUR: Python introuvable pour les comparaisons de versions."
  exit 1
fi

should_skip_dir() {
  case "$(basename "$1")" in
    .venv|__pycache__|.git|.idea|_logs|_logs_*) return 0 ;;
    .*) return 0 ;;
  esac
  return 1
}

is_python_project() {
  local dir="$1"
  [[ -f "$dir/main.py" ]] || [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]] \
    || [[ -d "$dir/app" ]] || [[ -d "$dir/src" ]]
}

normalize_pkg_name() {
  local spec="$1"
  spec="${spec%%[*]}"
  spec="${spec%%[<>=!~]*}"
  spec="${spec%%;*}"
  echo "$spec" | tr '[:upper:]_' '[:lower:]-' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

generate_project_requirements() {
  local project="$1" out_file="$2"
  : >"$out_file"
  local line spec projects part
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$line" || "$line" != *"|"* ]] && continue
    spec="${line%%|*}"
    spec="$(echo "$spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    projects="${line#*|}"
    projects="$(echo "$projects" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [[ "$projects" == "ALL" || "$projects" == "all" ]]; then
      echo "$spec" >>"$out_file"
      continue
    fi
    IFS=',' read -ra _projs <<< "$projects"
    for part in "${_projs[@]}"; do
      part="$(echo "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ "$part" == "$project" ]] && echo "$spec" >>"$out_file"
    done
  done <"$REQUIREMENTS_MATRIX"
  sort -u "$out_file" -o "$out_file"
}

get_installed_version() {
  "$1" show "$2" 2>/dev/null | awk -F': ' '/^Version:/{gsub(/^[ \t]+/,"",$2); print $2; exit}'
}

get_latest_pypi_version() {
  local venv_pip="$1" pkg="$2" line latest
  line="$("$venv_pip" index versions "$pkg" 2>/dev/null | head -n1)" || true
  latest="$(printf '%s' "$line" | sed -n 's/.*(\(.*\)).*/\1/p')"
  if [[ -z "$latest" ]]; then
    latest="$(printf '%s' "$line" | sed -n 's/.*Available versions: *\([^ ]*\).*/\1/p')"
  fi
  [[ -n "$latest" ]] && printf '%s' "$latest" || printf 'N/A'
}

compare_versions_status() {
  "$PYTHON_BIN" - "$1" "$2" <<'PY' 2>/dev/null || echo "UNKNOWN"
import re, sys
cur, lat = sys.argv[1].strip(), sys.argv[2].strip()
if not cur or cur == "ABSENT":
    print("MISSING"); raise SystemExit
if not lat or lat == "N/A":
    print("UNKNOWN"); raise SystemExit
def norm(v):
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
print("UPDATE" if norm(cur) < norm(lat) else "OK")
PY
}

compare_matrix_target_status() {
  "$PYTHON_BIN" - "$1" "$2" <<'PY' 2>/dev/null || echo "A_VERIFIER"
import re, sys
spec, cur = sys.argv[1].strip(), sys.argv[2].strip()
if not spec or not cur or cur == "ABSENT":
    print("A_VERIFIER"); raise SystemExit
m = re.match(r"^([A-Za-z0-9_.\-]+)\s*([<>=!~]+)\s*([A-Za-z0-9_.!\-+]+)", spec)
if not m:
    print("LIBRE"); raise SystemExit
op, tgt = m.group(2), m.group(3)
def norm(v):
    v = v.lower().replace("-", ".")
    parts = []
    for token in re.split(r"[._+]", v):
        if token == "post":
            parts.append(0)
            continue
        m2 = re.match(r"^(\d+)", token)
        parts.append(int(m2.group(1)) if m2 else 0)
    while len(parts) < 8:
        parts.append(0)
    return tuple(parts[:8])
try:
    cv, tv = norm(cur), norm(tgt)
    if op in {">=", "==", "~="}:
        if cv > tv:
            print("MATRICE_A_RAFRAICHIR")
        elif cv == tv:
            print("OK")
        else:
            print("MATRICE_SUPERIEURE")
    else:
        print("A_VERIFIER")
except Exception:
    print("A_VERIFIER")
PY
}

write_matrix_refresh_row() {
  local project="$1" pkg="$2" spec="$3" current="$4" matrix_status="$5"
  [[ "$matrix_status" != "MATRICE_A_RAFRAICHIR" ]] && return 0
  local suggested="${pkg}>=${current}"
  printf '%s | %s | %s | installé=%s | suggéré=%s\n' \
    "$project" "$pkg" "$spec" "$current" "$suggested" >>"$MATRIX_CHECK_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$project" "$pkg" "$spec" "$current" "$suggested" >>"$MATRIX_REFRESH_TSV"
}

pick_row_color() {
  local pypi_label="$1" matrix_label="$2"
  if [[ "$pypi_label" == "ABSENT" || "$matrix_label" == "MATRICE_SUPERIEURE" ]]; then
    echo "$RED"
  elif [[ "$pypi_label" == "A_CHECKER" || "$matrix_label" == "MATRICE_A_RAFRAICHIR" ]]; then
    echo "$YELLOW"
  elif [[ "$pypi_label" == "A_VERIFIER" || "$matrix_label" == "A_VERIFIER" ]]; then
    echo "$YELLOW"
  elif [[ "$matrix_label" == "LIBRE" ]]; then
    echo "$CYAN"
  else
    echo "$GREEN"
  fi
}

check_project_package_versions() {
  local project="$1" project_dir="$2" requirements_file="$3"
  local venv_python="$project_dir/.venv/bin/python"
  local venv_pip="$project_dir/.venv/bin/pip"

  echo "" | tee -a "$PACKAGE_CHECK_FILE"
  echo "[$project]" | tee -a "$PACKAGE_CHECK_FILE"

  if [[ ! -x "$venv_python" ]]; then
    printf "${RED}%-18s %-18s %-26s %-18s %-14s %-24s${RESET}\n" \
      "Package" "Actuelle" "Cible matrice" "Dernière PyPI" "Statut PyPI" "Statut Matrice"
    printf "${RED}%-18s %-18s %-26s %-18s %-14s %-24s${RESET}\n" \
      "VENV_ABSENT" "ABSENT" "N/A" "N/A" "ERREUR" "A_VERIFIER" | tee -a "$PACKAGE_CHECK_FILE"
    MATRIX_REFRESH_COUNT=$((MATRIX_REFRESH_COUNT + 0))
    PYPI_UPDATE_COUNT=$((PYPI_UPDATE_COUNT + 0))
    return 0
  fi

  if [[ ! -s "$requirements_file" ]]; then
    printf "${YELLOW}%-18s %-18s %-26s %-18s %-14s %-24s${RESET}\n" \
      "AUCUNE_MATRICE" "N/A" "N/A" "N/A" "SANS_MATRICE" "SANS_MATRICE" | tee -a "$PACKAGE_CHECK_FILE"
    NO_MATRIX_COUNT=$((NO_MATRIX_COUNT + 1))
    return 0
  fi

  printf "%-18s %-18s %-26s %-18s %-14s %-24s\n" \
    "Package" "Actuelle" "Cible matrice" "Dernière PyPI" "Statut PyPI" "Statut Matrice" | tee -a "$PACKAGE_CHECK_FILE"
  printf "%-18s %-18s %-26s %-18s %-14s %-24s\n" \
    "------------------" "------------------" "--------------------------" "------------------" "--------------" "------------------------" | tee -a "$PACKAGE_CHECK_FILE"

  local spec pkg current latest status matrix_status pypi_label matrix_label color
  while IFS= read -r spec || [[ -n "$spec" ]]; do
    spec="$(echo "$spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$spec" ]] && continue
    pkg="$(normalize_pkg_name "$spec")"
    current="$(get_installed_version "$venv_pip" "$pkg")"
    if [[ -z "$current" ]]; then
      current="ABSENT"
      latest="N/A"
      status="MISSING"
    else
      latest="$(get_latest_pypi_version "$venv_pip" "$pkg")"
      status="$(compare_versions_status "$current" "$latest")"
    fi
    matrix_status="$(compare_matrix_target_status "$spec" "$current")"

    case "$status" in
      OK) pypi_label="A_JOUR" ;;
      UPDATE) pypi_label="A_CHECKER"; PYPI_UPDATE_COUNT=$((PYPI_UPDATE_COUNT + 1)) ;;
      MISSING) pypi_label="ABSENT" ;;
      *) pypi_label="A_VERIFIER" ;;
    esac

    case "$matrix_status" in
      OK) matrix_label="OK" ;;
      MATRICE_A_RAFRAICHIR) matrix_label="MATRICE_A_RAFRAICHIR"; MATRIX_REFRESH_COUNT=$((MATRIX_REFRESH_COUNT + 1)) ;;
      MATRICE_SUPERIEURE) matrix_label="MATRICE_SUPERIEURE" ;;
      LIBRE) matrix_label="LIBRE" ;;
      *) matrix_label="A_VERIFIER" ;;
    esac

    write_matrix_refresh_row "$project" "$pkg" "$spec" "$current" "$matrix_status"
    color="$(pick_row_color "$pypi_label" "$matrix_label")"
    printf "${color}%-18s %-18s %-26s %-18s %-14s %-24s${RESET}\n" \
      "$pkg" "$current" "$spec" "$latest" "$pypi_label" "$matrix_label" | tee -a "$PACKAGE_CHECK_FILE"
  done <"$requirements_file"
}

discover_projects() {
  local d name
  for d in "$PROJECTS_ROOT"/*; do
    [[ -d "$d" ]] || continue
    should_skip_dir "$d" && continue
    name="$(basename "$d")"
    is_python_project "$d" || continue
    echo "$name"
  done | sort -u
}

MATRIX_REFRESH_COUNT=0
PYPI_UPDATE_COUNT=0
NO_MATRIX_COUNT=0

run_audit() {
  if [[ ! -f "$REQUIREMENTS_MATRIX" ]]; then
    log_err "Matrice introuvable: $REQUIREMENTS_MATRIX"
    exit 1
  fi

  print_section "AUDIT PACKAGES — PACKAGE UPDATER"
  echo "Date           : $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Python         : $PYTHON_BIN"
  echo "Projets        : $PROJECTS_ROOT"
  echo "Matrice        : $REQUIREMENTS_MATRIX"
  echo "Dossier run    : $LOG_DIR"
  echo "Dossier output : $OUTPUT_DIR"

  {
    echo "CHECK PACKAGES — $RUN_TS"
    echo "Matrice : $REQUIREMENTS_MATRIX"
    echo ""
  } >"$PACKAGE_CHECK_FILE"

  {
    echo "CHECK MATRICE — $RUN_TS"
    echo "Lignes où la version minimale est inférieure à la version installée."
    echo "Format : projet | package | cible_actuelle | installé | suggéré"
    echo ""
  } >"$MATRIX_CHECK_FILE"

  printf 'project\tpackage\told_spec\tinstalled\tsuggested_spec\n' >"$MATRIX_REFRESH_TSV"

  : >"$PROJECT_RECORDS"
  local project project_dir req_file
  while IFS= read -r project; do
    [[ -z "$project" ]] && continue
    project_dir="$PROJECTS_ROOT/$project"
    req_file="${LOG_DIR}/requirements_${project}.txt"
    generate_project_requirements "$project" "$req_file"
    printf '%s\t%s\t%s\n' "$project" "$project_dir" "$req_file" >>"$PROJECT_RECORDS"
  done < <(discover_projects)

  print_section "CHECK DES NOUVELLES VERSIONS PACKAGES"
  echo "Objectif : détail par appli + vérifier si la matrice minimale est en retard."
  echo "Aucune mise à jour n'est appliquée par ce bloc."
  echo "Statut PyPI    : ${GREEN}A_JOUR${RESET} / ${YELLOW}A_CHECKER${RESET} / ${RED}ABSENT${RESET} / ${YELLOW}A_VERIFIER${RESET}"
  echo "Statut Matrice : ${GREEN}OK${RESET} / ${YELLOW}MATRICE_A_RAFRAICHIR${RESET} / ${RED}MATRICE_SUPERIEURE${RESET} / ${CYAN}LIBRE${RESET}"
  echo "Rapport        : $PACKAGE_CHECK_FILE"
  echo "Matrice        : $MATRIX_CHECK_FILE"

  while IFS=$'\t' read -r project project_dir req_file; do
    [[ -n "$project" ]] || continue
    check_project_package_versions "$project" "$project_dir" "$req_file"
  done <"$PROJECT_RECORDS"

  print_section "SYNTHÈSE MATRICE À RAFRAÎCHIR"
  if [[ "$MATRIX_REFRESH_COUNT" -gt 0 ]]; then
    log_warn "$MATRIX_REFRESH_COUNT ligne(s) : matrice minimale < version installée."
    echo "Édition manuelle : $REQUIREMENTS_MATRIX"
    echo "Auto             : ./package-updater.sh apply-matrix $LOG_DIR"
    echo ""
    cat "$MATRIX_CHECK_FILE"
  else
    log_ok "Aucune cible minimale à rafraîchir."
  fi

  if [[ "$PYPI_UPDATE_COUNT" -gt 0 ]]; then
    echo ""
    log_warn "$PYPI_UPDATE_COUNT package(s) : version PyPI plus récente que l'installé (A_CHECKER)."
    echo "Relancer un venv install dans installer si vous souhaitez upgrader les .venv."
  fi

  {
    echo "Résumé audit — $RUN_TS"
    echo "Matrice à rafraîchir (MATRICE_A_RAFRAICHIR) : $MATRIX_REFRESH_COUNT"
    echo "PyPI plus récent (A_CHECKER)                : $PYPI_UPDATE_COUNT"
    echo "Projets sans entrée matrice                 : $NO_MATRIX_COUNT"
    echo ""
    echo "Fichiers :"
    echo "  package_check.txt  — tableaux par projet"
    echo "  matrix_check.txt   — suggestions matrice"
    echo "  matrix_refresh.tsv — import apply-matrix"
  } >"$SUMMARY_FILE"

  {
    echo "LOG_DIR=$LOG_DIR"
    echo "OUTPUT_DIR=$OUTPUT_DIR"
    echo "PACKAGE_CHECK=$PACKAGE_CHECK_FILE"
    echo "MATRIX_CHECK=$MATRIX_CHECK_FILE"
    echo "MATRIX_REFRESH_TSV=$MATRIX_REFRESH_TSV"
    echo "SUMMARY=$SUMMARY_FILE"
  } >"$PATHS_FILE"

  ln -sfn "$LOG_DIR" "${LOG_BASE_DIR}/latest" 2>/dev/null || true

  print_section "RÉSUMÉ FINAL"
  cat "$SUMMARY_FILE"
  echo ""
  log_ok "Audit terminé. Ouvrir : $OUTPUT_DIR"
}

# stdout → journal app (Process) + run.log sur disque
run_audit 2>&1 | tee -a "$LOG_FILE"
exit "${PIPESTATUS[0]}"
