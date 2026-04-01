#!/usr/bin/env bash
# shelly — copy dotfiles from repo config/

shelly_install_plain_dotfile() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -f "$src" ]; then
    log_fail "missing template: $src"
    return 1
  fi

  if [ -f "$dst" ] || [ -L "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      log_ok "$label is already up to date (matches $(basename "$src"))"
      shelly_inc_present
      return 0
    fi
    log_info "$label differs from $(basename "$src")"
    backup_file "$dst" || return 1
    log_work "writing new $label..."
  else
    log_work "creating $label..."
  fi

  if ! mkdir -p "$(dirname "$dst")"; then
    log_fail "mkdir failed: $(dirname "$dst")"
    return 1
  fi
  if ! cp "$src" "$dst"; then
    log_fail "cp failed: $dst"
    return 1
  fi
  log_ok "$label installed"
  shelly_inc_installed
  return 0
}

shelly_install_git_identity() {
  local dst="$HOME/.gitconfig"
  local name="" email=""

  if [ -f "$dst" ]; then
    name=$(git config -f "$dst" user.name 2>/dev/null | head -1 || true)
    email=$(git config -f "$dst" user.email 2>/dev/null | head -1 || true)
  fi

  if [ -n "$name" ] && [ -n "$email" ]; then
    log_ok "~/.gitconfig already has user.name and user.email — leaving file unchanged"
    shelly_inc_present
    return 0
  fi

  if [ ! -t 0 ]; then
    log_fail "git user.name / user.email missing and no TTY to prompt — set them manually or run interactively"
    return 1
  fi

  [ -n "$name" ] || read -r -p "  Git user.name: " name
  [ -n "$email" ] || read -r -p "  Git user.email: " email

  if [ -z "$name" ] || [ -z "$email" ]; then
    log_fail "user.name and user.email are required"
    return 1
  fi

  log_work "configuring git user identity (git config --global)..."
  if ! git config --global user.name "$name"; then
    log_fail "git config user.name failed"
    return 1
  fi
  if ! git config --global user.email "$email"; then
    log_fail "git config user.email failed"
    return 1
  fi
  log_ok "git user.name and user.email configured"
  shelly_inc_installed
  return 0
}

shelly_install_git_aliases() {
  log_work "ensuring git alias lg (color graph log)..."
  if ! git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"; then
    log_fail "git config alias.lg failed"
    return 1
  fi
  log_ok "git alias lg configured — run: git lg"
  return 0
}

step_dotfiles() {
  log_step 3 5 "Dotfiles"

  local cfg="$SHELLY_ROOT/config"

  shelly_install_plain_dotfile "$cfg/zshrc" "$HOME/.zshrc" "~/.zshrc" || return 1
  shelly_install_plain_dotfile "$cfg/zshenv" "$HOME/.zshenv" "~/.zshenv" || return 1
  shelly_install_plain_dotfile "$cfg/vimrc" "$HOME/.vimrc" "~/.vimrc" || return 1

  # Ghostty (macOS): default config path per ghostty(5)
  local ghostty_dst="${HOME}/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
  shelly_install_plain_dotfile "$cfg/ghostty/config.ghostty" "$ghostty_dst" "Ghostty config.ghostty" || return 1

  shelly_install_git_identity || return 1
  shelly_install_git_aliases || return 1

  return 0
}
