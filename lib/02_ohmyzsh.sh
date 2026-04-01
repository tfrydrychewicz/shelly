#!/usr/bin/env bash
# shelly — Oh My Zsh

step_ohmyzsh() {
  log_step 2 5 "Oh My Zsh"

  if [ -d "$HOME/.oh-my-zsh" ]; then
    log_ok "~/.oh-my-zsh already exists"
    shelly_inc_present
  else
    log_work "cloning Oh My Zsh into ~/.oh-my-zsh..."
    if ! git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"; then
      log_fail "git clone oh-my-zsh failed"
      return 1
    fi
    log_ok "Oh My Zsh cloned"
    shelly_inc_installed
  fi

  local login_shell=""
  if [ -n "${USER:-}" ]; then
    login_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '/^UserShell:/{print $2}')
  fi
  log_info "login shell (dscl): ${login_shell:-unknown}"

  if [ "${login_shell:-}" = "/bin/zsh" ]; then
    log_ok "default login shell is already /bin/zsh"
    shelly_inc_present
  else
    log_work "setting default login shell to /bin/zsh (may prompt for password)..."
    if chsh -s /bin/zsh; then
      log_ok "chsh succeeded — reopen Terminal for login shell to take effect"
      shelly_inc_installed
    else
      log_warn "chsh failed — run manually: chsh -s /bin/zsh"
    fi
  fi

  return 0
}
