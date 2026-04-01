#!/usr/bin/env bash
# shelly — bootstrap macOS shell environment (see DESIGN.md)

set -u

SHELLY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SHELLY_ROOT

export SHELLY_BACKUP_SESSION
SHELLY_BACKUP_SESSION="$(date +%Y%m%d_%H%M%S)"
export SHELLY_BACKUP_ROOT="${HOME}/.shelly_backups/${SHELLY_BACKUP_SESSION}"
mkdir -p "$SHELLY_BACKUP_ROOT"

SHELLY_START_TS=$(date +%s)
SHELLY_STEPS_TOTAL=5
SHELLY_STEPS_PASSED=0

# shellcheck source=lib/utils.sh
# shellcheck disable=SC1091
source "${SHELLY_ROOT}/lib/utils.sh"

trap 'printf "\n"; log_warn "Interrupted — backups (if any): ${SHELLY_BACKUP_ROOT}"; exit 130' INT

shelly_preflight() {
  printf '\n%s[Preflight]%s\n' "$BOLD" "$RESET"

  if [ "$(id -u)" -eq 0 ]; then
    log_fail "do not run shelly as root"
    exit 1
  fi
  log_ok "not running as root"

  if [ "$(uname -s)" != "Darwin" ]; then
    log_fail "shelly supports macOS (Darwin) only"
    exit 1
  fi
  log_ok "host OS: $(uname -sr)"

  log_ok "architecture: $(uname -m)"
  log_info "backup session directory: $SHELLY_BACKUP_ROOT"

  if ping -c 1 -W 3000 github.com >/dev/null 2>&1; then
    log_ok "network: github.com responded to ping"
  elif curl -fsSI --connect-timeout 10 https://github.com >/dev/null 2>&1; then
    log_ok "network: https://github.com reachable (curl; ICMP may be blocked)"
  else
    log_fail "network: cannot reach github.com — fix connectivity and retry"
    exit 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_fail "git not found — install Xcode Command Line Tools first (xcode-select --install)"
    exit 1
  fi
  log_ok "git available: $(command -v git)"

  return 0
}

shelly_run_step() {
  local fn="$1"
  if "$fn"; then
    SHELLY_STEPS_PASSED=$((SHELLY_STEPS_PASSED + 1))
    return 0
  fi
  return 1
}

main() {
  printf '%s\n' "${BOLD}shelly — macOS shell bootstrap${RESET}"
  log_info "repo root: $SHELLY_ROOT"

  shelly_preflight || exit 1

  # shellcheck disable=SC1091
  source "${SHELLY_ROOT}/lib/01_homebrew.sh"
  shelly_run_step step_homebrew || exit 1

  # shellcheck disable=SC1091
  source "${SHELLY_ROOT}/lib/02_ohmyzsh.sh"
  shelly_run_step step_ohmyzsh || exit 1

  # shellcheck disable=SC1091
  source "${SHELLY_ROOT}/lib/03_dotfiles.sh"
  shelly_run_step step_dotfiles || exit 1

  # shellcheck disable=SC1091
  source "${SHELLY_ROOT}/lib/04_vim.sh"
  shelly_run_step step_vim || exit 1

  # shellcheck disable=SC1091
  source "${SHELLY_ROOT}/lib/05_nvm_node.sh"
  shelly_run_step step_nvm_node || exit 1

  local end_ts elapsed
  end_ts=$(date +%s)
  elapsed=$((end_ts - SHELLY_START_TS))

  printf '\n%s════════════════════════════════════════%s\n' "$BOLD" "$RESET"
  printf '  shelly finished in %ss\n' "$elapsed"
  printf '  Steps passed:  %s/%s\n' "$SHELLY_STEPS_PASSED" "$SHELLY_STEPS_TOTAL"
  printf '  Items installed (approx.): %s   already present: %s\n' "$SHELLY_ITEMS_INSTALLED" "$SHELLY_ITEMS_PRESENT"
  printf '  Backups created: %s   (under %s)\n' "$SHELLY_BACKUPS_CREATED" "$SHELLY_BACKUP_ROOT"
  printf '%s════════════════════════════════════════%s\n' "$BOLD" "$RESET"
  log_ok "open a new terminal (or run: source ~/.zshrc) to load nvm and your prompt"
}

main "$@"
