#!/bin/bash
# Découverte / rattachement de nouveaux projets Python sur la matrice existante.

project_attachments_init() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/PycharmProjects}"
  REPO_ROOT="${PACKAGE_UPDATER_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
  LOG_BASE_DIR="${LOG_BASE_DIR:-$HOME/Documents/AlphaLagoon/_logs_XcodeProjects/package_updater}"
  DEFAULT_MATRIX="${REQUIREMENTS_MATRIX:-$REPO_ROOT/package_updater_latest_matrix.txt}"
  REQUIREMENTS_MATRIX="${REQUIREMENTS_MATRIX:-$DEFAULT_MATRIX}"
  MATRIX_ATTACH_TSV="${MATRIX_ATTACH_TSV:-$LOG_BASE_DIR/audit_matrix_attach.tsv}"
  MATRIX_ATTACH_COUNT=0
}

project_attachments_normalize_pkg_name() {
  local spec="$1"
  spec="${spec%%[*]}"
  spec="${spec%%[<>=!~]*}"
  spec="${spec%%;*}"
  echo "$spec" | tr '[:upper:]_' '[:lower:]-' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

project_attachments_reference_for() {
  local project="$1"
  if [[ "$project" == *"_rsi_"* ]]; then
    echo "${project/_rsi_/_ma_}"
    return 0
  fi
  echo ""
}

project_attachments_listed_on_line() {
  local projects_col="$1" project="$2"
  local part
  IFS=',' read -ra _plist <<< "$projects_col"
  for part in "${_plist[@]}"; do
    part="$(echo "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ "$part" == "$project" ]] && return 0
  done
  return 1
}

project_attachments_installed_version() {
  "$1" show "$2" 2>/dev/null | awk -F': ' '/^Version:/{gsub(/^[ \t]+/,"",$2); print $2; exit}'
}

project_attachments_pkg_installed() {
  local venv_pip="$1" pkg="$2"
  local current
  current="$(project_attachments_installed_version "$venv_pip" "$pkg")"
  [[ -n "$current" ]]
}

project_attachments_should_skip_dir() {
  case "$(basename "$1")" in
    .venv|__pycache__|.git|.idea) return 0 ;;
    .*) return 0 ;;
  esac
  return 1
}

project_attachments_is_python_project() {
  local dir="$1"
  [[ -f "$dir/main.py" ]] || [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]] \
    || [[ -d "$dir/app" ]] || [[ -d "$dir/src" ]]
}

project_attachments_discover_projects() {
  local d name
  for d in "$PROJECTS_ROOT"/*; do
    [[ -d "$d" ]] || continue
    project_attachments_should_skip_dir "$d" && continue
    name="$(basename "$d")"
    project_attachments_is_python_project "$d" || continue
    echo "$name"
  done | sort -u
}

project_attachments_generate_requirements() {
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

project_attachments_suggest_reference() {
  local project="$1" project_dir="$2"
  local ref venv_pip line spec projects pkg installed
  ref="$(project_attachments_reference_for "$project")"
  [[ -z "$ref" ]] && return 0
  venv_pip="$project_dir/.venv/bin/pip"
  [[ -x "$venv_pip" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$line" || "$line" != *"|"* ]] && continue
    spec="${line%%|*}"
    spec="$(echo "$spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    projects="${line#*|}"
    projects="$(echo "$projects" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ "$projects" == "ALL" || "$projects" == "all" ]] && continue
    project_attachments_listed_on_line "$projects" "$ref" || continue
    project_attachments_listed_on_line "$projects" "$project" && continue
    pkg="$(project_attachments_normalize_pkg_name "$spec")"
    project_attachments_pkg_installed "$venv_pip" "$pkg" || continue
    installed="$(project_attachments_installed_version "$venv_pip" "$pkg")"
    printf '%s\t%s\t%s\t%s\tattach\n' "$project" "$pkg" "$spec" "$installed" >>"$MATRIX_ATTACH_TSV"
    MATRIX_ATTACH_COUNT=$((MATRIX_ATTACH_COUNT + 1))
  done <"$REQUIREMENTS_MATRIX"
}

project_attachments_suggest_unmapped() {
  local project="$1" project_dir="$2"
  local venv_pip line spec projects pkg installed
  venv_pip="$project_dir/.venv/bin/pip"
  [[ -x "$venv_pip" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$line" || "$line" != *"|"* ]] && continue
    spec="${line%%|*}"
    spec="$(echo "$spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    projects="${line#*|}"
    projects="$(echo "$projects" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ "$projects" == "ALL" || "$projects" == "all" ]] && continue
    project_attachments_listed_on_line "$projects" "$project" && continue
    pkg="$(project_attachments_normalize_pkg_name "$spec")"
    project_attachments_pkg_installed "$venv_pip" "$pkg" || continue
    installed="$(project_attachments_installed_version "$venv_pip" "$pkg")"
    printf '%s\t%s\t%s\t%s\tattach\n' "$project" "$pkg" "$spec" "$installed" >>"$MATRIX_ATTACH_TSV"
    MATRIX_ATTACH_COUNT=$((MATRIX_ATTACH_COUNT + 1))
  done <"$REQUIREMENTS_MATRIX"
}

project_attachments_discover() {
  project_attachments_init
  local work_dir project_records project project_dir req_file ref
  if [[ ! -f "$REQUIREMENTS_MATRIX" ]]; then
    echo "ERREUR: matrice introuvable: $REQUIREMENTS_MATRIX" >&2
    return 1
  fi

  mkdir -p "$LOG_BASE_DIR"
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/pkgupd_attach.XXXX")"
  project_records="${work_dir}/project_records.tsv"
  trap 'rm -rf "$work_dir"' RETURN

  printf 'project\tpackage\tmatrix_spec\tinstalled\taction\n' >"$MATRIX_ATTACH_TSV"
  : >"$project_records"

  while IFS= read -r project; do
    [[ -z "$project" ]] && continue
    project_dir="$PROJECTS_ROOT/$project"
    req_file="${work_dir}/requirements_${project}.txt"
    project_attachments_generate_requirements "$project" "$req_file"
    printf '%s\t%s\t%s\n' "$project" "$project_dir" "$req_file" >>"$project_records"
  done < <(project_attachments_discover_projects)

  while IFS=$'\t' read -r project project_dir req_file; do
    [[ -n "$project" ]] || continue
    ref="$(project_attachments_reference_for "$project")"
    if [[ -n "$ref" ]]; then
      project_attachments_suggest_reference "$project" "$project_dir"
    elif [[ ! -s "$req_file" ]]; then
      project_attachments_suggest_unmapped "$project" "$project_dir"
    fi
  done <"$project_records"
}
