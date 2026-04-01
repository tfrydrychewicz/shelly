#!/usr/bin/env bash
# shelly — nvm, Node.js LTS, CoC extensions

step_nvm_node() {
  log_step 5 5 "nvm + Node.js"

  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  mkdir -p "$NVM_DIR"

  local nvm_sh
  nvm_sh="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
  if [ ! -s "$nvm_sh" ]; then
    log_fail "nvm.sh not found at $nvm_sh (brew formula nvm missing?)"
    return 1
  fi
  log_ok "sourcing nvm from $nvm_sh"
  # shellcheck disable=SC1090
  . "$nvm_sh"

  log_work "ensuring Node.js LTS is installed via nvm..."
  if nvm install --lts; then
    log_ok "nvm install --lts completed"
  else
    log_fail "nvm install --lts failed"
    return 1
  fi

  if nvm alias default 'lts/*' 2>/dev/null; then
    log_ok "nvm alias default -> lts/*"
  else
    log_warn "nvm alias default failed (non-fatal)"
  fi

  if ! nvm use --lts >/dev/null 2>&1 && ! nvm use default >/dev/null 2>&1; then
    log_warn "nvm use did not switch version in this shell (try: source ~/.zshrc)"
  fi

  if ! command -v node >/dev/null 2>&1; then
    log_fail "node not on PATH after nvm setup — open a new shell or: source nvm.sh && nvm use default"
    return 1
  fi

  log_ok "node $(node -v) / npm $(npm -v)"

  local VIM_BIN
  VIM_BIN=$(command -v vim)
  if [ -z "$VIM_BIN" ]; then
    log_warn "vim not found — skipping CoC extension install"
    return 0
  fi
  if [ ! -d "$HOME/.vim/plugged/coc.nvim" ]; then
    log_warn "coc.nvim plugin missing — skipping CoC extension install"
    return 0
  fi

  log_work "installing CoC extensions: coc-tsserver coc-json coc-go coc-pyright..."
  if "$VIM_BIN" -c 'CocInstall -sync coc-tsserver coc-json coc-go coc-pyright' -c 'qa'; then
    log_ok "CoCInstall finished"
  else
    log_warn "CoCInstall reported a problem — open vim and run :CocList extensions"
  fi

  return 0
}
