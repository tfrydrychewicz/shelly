#!/usr/bin/env bash
# shelly — shared logging and backup helpers

# Use $'...' so \033 becomes a real ESC; plain '\033' prints literally in the terminal.
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

SHELLY_ITEMS_INSTALLED="${SHELLY_ITEMS_INSTALLED:-0}"
SHELLY_ITEMS_PRESENT="${SHELLY_ITEMS_PRESENT:-0}"
SHELLY_BACKUPS_CREATED="${SHELLY_BACKUPS_CREATED:-0}"
SHELLY_STEPS_PASSED="${SHELLY_STEPS_PASSED:-0}"
SHELLY_STEPS_TOTAL="${SHELLY_STEPS_TOTAL:-5}"

shelly_inc_installed() { SHELLY_ITEMS_INSTALLED=$((SHELLY_ITEMS_INSTALLED + 1)); }
shelly_inc_present() { SHELLY_ITEMS_PRESENT=$((SHELLY_ITEMS_PRESENT + 1)); }
shelly_inc_backup() { SHELLY_BACKUPS_CREATED=$((SHELLY_BACKUPS_CREATED + 1)); }

log_step() {
  printf '\n%s[STEP %s/%s] %s%s\n' "$BOLD" "$1" "$2" "$3" "$RESET"
}

log_ok() {
  printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$*"
}

log_work() {
  printf '  %s●%s %s\n' "$YELLOW" "$RESET" "$*"
}

log_fail() {
  printf '  %s✗%s %s\n' "$RED" "$RESET" "$*" >&2
}

log_info() {
  printf '  %s→%s %s\n' "$CYAN" "$RESET" "$*"
}

log_warn() {
  printf '  %s⚠%s %s\n' "$YELLOW" "$RESET" "$*"
}

# Ensure backup session directory exists (single timestamp per run).
shelly_ensure_backup_root() {
  if [ -z "${SHELLY_BACKUP_ROOT:-}" ]; then
    log_fail "SHELLY_BACKUP_ROOT is not set"
    return 1
  fi
  mkdir -p "$SHELLY_BACKUP_ROOT" || return 1
}

# Backup a path into $SHELLY_BACKUP_ROOT if it exists.
backup_file() {
  local src="$1"
  [ -e "$src" ] || return 0
  shelly_ensure_backup_root || return 1
  local base
  base=$(basename "$src")
  cp -a "$src" "$SHELLY_BACKUP_ROOT/$base" || return 1
  shelly_inc_backup
  log_info "backed up $src to $SHELLY_BACKUP_ROOT/$base"
}

# Compare two files; true if same content (missing files differ).
shelly_files_match() {
  local a="$1"
  local b="$2"
  [ -f "$a" ] && [ -f "$b" ] && cmp -s "$a" "$b"
}
