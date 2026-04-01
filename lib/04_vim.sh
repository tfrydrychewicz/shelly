#!/usr/bin/env bash
# shelly — vim-plug and Vim plugins (CoC extensions run in step 5 after Node exists)

step_vim() {
  log_step 4 5 "Vim"

  local VIM_BIN
  VIM_BIN=$(command -v vim)
  if [ -z "$VIM_BIN" ]; then
    log_fail "vim not on PATH — ensure the Homebrew step completed"
    return 1
  fi
  log_ok "using vim binary: $VIM_BIN"

  local plug_vim="$HOME/.vim/autoload/plug.vim"
  if [ -f "$plug_vim" ]; then
    log_ok "vim-plug already present at $plug_vim"
    shelly_inc_present
  else
    log_work "installing vim-plug..."
    mkdir -p "$HOME/.vim/autoload"
    if ! curl -fLo "$plug_vim" --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
      log_fail "curl vim-plug failed"
      return 1
    fi
    log_ok "vim-plug installed"
    shelly_inc_installed
  fi

  local missing=0
  local pdir
  for pdir in auto-pairs coc.nvim fzf fzf.vim nerdtree vim-go vim-polyglot vim-fugitive \
    vim-gitgutter vim-code-dark vim-airline vim-airline-themes vim-startify \
    vim-devicons vim-ai vimspector; do
    if [ -d "$HOME/.vim/plugged/$pdir" ]; then
      log_ok "plugin directory present: $pdir"
    else
      log_info "plugin directory missing: $pdir"
      missing=1
    fi
  done

  if [ "$missing" -eq 1 ]; then
    log_work "running PlugInstall --sync (may take several minutes)..."
    if ! "$VIM_BIN" "+PlugInstall --sync" +qall; then
      log_fail "PlugInstall failed"
      return 1
    fi
    log_ok "PlugInstall finished"
    shelly_inc_installed
  fi

  missing=0
  for pdir in auto-pairs coc.nvim fzf fzf.vim nerdtree vim-go vim-polyglot vim-fugitive \
    vim-gitgutter vim-code-dark vim-airline vim-airline-themes vim-startify \
    vim-devicons vim-ai vimspector; do
    if [ ! -d "$HOME/.vim/plugged/$pdir" ]; then
      log_fail "plugin still missing after PlugInstall: $pdir"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    return 1
  fi

  log_ok "all expected plugin directories are present"
  log_info "CoC extensions will be installed in the nvm + Node step (requires node on PATH)"
  return 0
}
