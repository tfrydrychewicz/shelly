#!/usr/bin/env bash
# shelly — Homebrew, formulae, casks

# Homebrew refuses to install font casks if the same filenames already exist in
# ~/Library/Fonts (e.g. manual font drop-in). Back up to SHELLY_BACKUP_ROOT then remove.
shelly_backup_and_remove_conflicting_fragment_mono_fonts() {
  local fontfile
  shopt -s nullglob
  for fontfile in "$HOME/Library/Fonts"/FragmentMono*.ttf \
    "$HOME/Library/Fonts"/FragmentMono*.otf; do
    log_info "conflicting user font blocks cask; backing up then removing: $fontfile"
    backup_file "$fontfile" || {
      shopt -u nullglob
      return 1
    }
    rm -f "$fontfile" || {
      shopt -u nullglob
      return 1
    }
  done
  shopt -u nullglob
  return 0
}

step_homebrew() {
  log_step 1 5 "Homebrew"

  if command -v brew >/dev/null 2>&1; then
    log_ok "brew is already installed at $(command -v brew)"
    shelly_inc_present
  else
    log_work "installing Homebrew (official installer, NONINTERACTIVE)..."
    export NONINTERACTIVE=1
    if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      log_fail "Homebrew install failed"
      return 1
    fi
    log_ok "Homebrew installer finished"
    shelly_inc_installed
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    log_ok "loaded Apple Silicon brew into PATH ($(brew --prefix))"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
    log_ok "loaded Intel brew into PATH ($(brew --prefix))"
  else
    log_fail "brew executable not found under /opt/homebrew or /usr/local"
    return 1
  fi

  log_ok "machine architecture: $(uname -m)"
  log_ok "brew --prefix: $(brew --prefix)"

  local f
  for f in btop fzf grc lazygit lsd nvm pipx ripgrep vim z chroma; do
    if brew list --formula "$f" >/dev/null 2>&1; then
      log_ok "formula '$f' is already installed"
    else
      log_work "installing formula '$f'..."
      if ! brew install "$f"; then
        log_fail "brew install $f failed"
        return 1
      fi
      log_ok "formula '$f' installed successfully"
      shelly_inc_installed
    fi
  done

  # fzf: official helper wires Ctrl+T / Ctrl+R / Alt+C (shelly zshrc sources $(brew --prefix)/opt/fzf/shell/*.zsh)
  local fzf_install
  fzf_install="$(brew --prefix)/opt/fzf/install"
  if [ -x "$fzf_install" ]; then
    log_work "running fzf install (key-bindings + completion; zsh only; no auto-append to ~/.zshrc)..."
    if "$fzf_install" --all --no-update-rc --no-bash --no-fish; then
      log_ok "fzf install script finished"
    else
      log_warn "fzf install script exited non-zero — check $(brew --prefix)/opt/fzf; zsh integration may still work via zshrc"
    fi
  else
    log_warn "missing $fzf_install — skipping fzf install script"
  fi

  # Font casks live in the default homebrew/cask tap.
  log_ok "installing casks from default homebrew/cask"

  local c
  for c in ghostty font-fragment-mono; do
    if brew list --cask "$c" >/dev/null 2>&1; then
      log_ok "cask '$c' is already installed"
    else
      log_work "installing cask '$c'..."
      if [ "$c" = "font-fragment-mono" ]; then
        shelly_backup_and_remove_conflicting_fragment_mono_fonts || return 1
      fi
      if ! brew install --cask "$c"; then
        if [ "$c" = "font-fragment-mono" ]; then
          log_warn "first cask install failed — clearing Fragment Mono files in ~/Library/Fonts and retrying once..."
          shelly_backup_and_remove_conflicting_fragment_mono_fonts || return 1
          if brew install --cask "$c"; then
            log_ok "cask '$c' installed successfully (after retry)"
            shelly_inc_installed
            continue
          fi
        fi
        log_fail "brew install --cask $c failed"
        return 1
      fi
      log_ok "cask '$c' installed successfully"
      shelly_inc_installed
    fi
  done

  # shell-gpt → sgpt CLI (PyPI), isolated via pipx
  if ! command -v pipx >/dev/null 2>&1; then
    log_fail "pipx not on PATH after brew — cannot install sgpt"
    return 1
  fi
  log_ok "pipx available at $(command -v pipx)"

  export PATH="${HOME}/.local/bin:${PATH}"

  if command -v sgpt >/dev/null 2>&1; then
    log_ok "sgpt already on PATH ($(command -v sgpt))"
    shelly_inc_present
  elif pipx list 2>/dev/null | grep -qiE 'package shell-gpt|^shell-gpt '; then
    log_warn "shell-gpt is in pipx but sgpt not on PATH — open a new shell (shelly zshrc includes ~/.local/bin)"
    shelly_inc_present
  else
    log_work "installing shell-gpt via pipx (command: sgpt)..."
    if ! pipx install shell-gpt; then
      log_fail "pipx install shell-gpt failed"
      return 1
    fi
    log_ok "shell-gpt installed — configure API keys with sgpt or ~/.config/shell_gpt"
    shelly_inc_installed
  fi

  if command -v sgpt >/dev/null 2>&1; then
    log_ok "sgpt verified: $(sgpt --version 2>/dev/null || echo 'run sgpt --help')"
  fi

  log_ok "all formulae (incl. btop, fzf, lazygit, lsd), casks (ghostty, font-fragment-mono), and sgpt verified for this step"
  return 0
}
