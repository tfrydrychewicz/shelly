# Shelly — System Design

> A single-command macOS shell environment bootstrapper.
> Run it on a fresh Mac or an existing one — it figures out what's missing and installs only that.

---

## 1. Goals & Constraints

| Goal | Detail |
|------|--------|
| **Idempotent** | Safe to run repeatedly. Every step checks current state before acting. |
| **Verbose** | Every check prints a clear status line: what it's inspecting, whether it passed or needs action, and what it did. |
| **Fresh or existing** | Works on a brand-new macOS with nothing installed, or on a configured Mac where most things already exist. |
| **Shell-focused** | Only installs tooling related to the terminal/shell experience. The sole language runtime is nvm + Node.js. |
| **Zero dependencies** | The entrypoint is a single POSIX-compatible shell script (`install.sh`). No curl-pipe-bash from the internet at runtime beyond Homebrew's own installer and git clones. |
| **Non-destructive** | Existing dotfiles are backed up (timestamped) before being replaced. The user is never surprised. |

---

## 2. Architecture Overview

```
shelly/
├── install.sh              # Entrypoint — orchestrator script
├── config/                 # Dotfiles and config templates
│   ├── zshrc               # .zshrc contents
│   ├── zshenv              # .zshenv contents
│   ├── vimrc               # .vimrc contents
│   └── gitconfig           # .gitconfig template (name/email placeholders)
├── lib/                    # Modular step scripts, sourced by install.sh
│   ├── utils.sh            # Logging, colors, backup, link helpers
│   ├── 01_homebrew.sh      # Homebrew install + formulae + casks
│   ├── 02_ohmyzsh.sh       # Oh My Zsh framework
│   ├── 03_dotfiles.sh      # Symlink/copy dotfiles into $HOME
│   ├── 04_vim.sh           # vim-plug + plugin install + CoC extensions
│   └── 05_nvm_node.sh      # nvm + Node.js LTS
└── DESIGN.md               # This file
```

### Execution model

`install.sh` sources `lib/utils.sh` then runs each numbered step script **in order**.
Each step script exposes a single function (e.g., `step_homebrew`) that:

1. **Checks** whether the component is already present/correct.
2. **Prints** a status line for every sub-check.
3. **Installs/repairs** only what is missing.
4. **Verifies** the result and prints pass/fail.

If any step fails fatally, the script stops with a clear error. Non-fatal warnings (e.g., "formula already installed") continue.

---

## 3. Logging & Output Contract

Every line the user sees follows a strict visual format:

```
[STEP 1/5] Homebrew
  ✓ brew is already installed at /opt/homebrew/bin/brew
  ✓ formula 'vim' is already installed
  ● installing formula 'grc'...
  ✓ formula 'grc' installed successfully
  ✓ cask 'ghostty' is already installed
  ✓ all 5 formulae and 1 cask verified
```

Symbols:
- `✓` — check passed, nothing to do (green)
- `●` — action in progress (yellow)
- `✗` — failure (red)
- `→` — informational / skipped (cyan)

A final summary block prints at the end:

```
════════════════════════════════════════
  shelly finished in 74s
  Steps passed:  5/5
  Items installed: 3   (already present: 22)
  Backups created: 2   (in ~/.shelly_backups/20260401_071500/)
════════════════════════════════════════
```

---

## 4. Step-by-Step Design

### Step 1 — Homebrew (`01_homebrew.sh`)

| Check | Action |
|-------|--------|
| `command -v brew` | Install via the official Homebrew installer script |
| `brew --prefix` returns `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel) | Verify arch |
| Each formula in the manifest is installed | `brew install <formula>` for missing ones |
| Each cask in the manifest is installed | `brew install --cask <cask>` for missing ones |

**Manifests** (hardcoded in the script, derived from your machine):

```sh
FORMULAE=(
  grc           # Generic Colorizer — colorizes terminal output
  nvm           # Node Version Manager
  ripgrep       # rg — fast recursive grep
  vim           # Vim editor (latest, not macOS system vim)
  z             # Directory frecency jumper
)

CASKS=(
  ghostty       # GPU-accelerated terminal emulator
)
```

Note: transitive dependencies (openssl, readline, etc.) are handled by Homebrew automatically and are not listed.

---

### Step 2 — Oh My Zsh (`02_ohmyzsh.sh`)

| Check | Action |
|-------|--------|
| `~/.oh-my-zsh/` directory exists | Clone via `git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh` (unattended, no auto-chsh) |
| Default shell is zsh | `chsh -s /bin/zsh` if needed |

No custom (third-party) plugins detected — all five plugins (`git`, `z`, `nvm`, `colorize`, `grc`) are bundled with Oh My Zsh.

---

### Step 3 — Dotfiles (`03_dotfiles.sh`)

For each dotfile:

| Source (in repo) | Target | Strategy |
|-----------------|--------|----------|
| `config/zshrc` | `~/.zshrc` | Copy (not symlink — keeps working if repo is deleted) |
| `config/zshenv` | `~/.zshenv` | Copy |
| `config/vimrc` | `~/.vimrc` | Copy |
| `config/gitconfig` | `~/.gitconfig` | Copy with interactive name/email prompt if placeholders detected |

**Backup strategy:**

Before overwriting any existing dotfile, the script:
1. Creates `~/.shelly_backups/<timestamp>/`
2. Copies the existing file there
3. Prints `→ backed up ~/.zshrc to ~/.shelly_backups/20260401_071500/.zshrc`

**Diffing:**

If the target file already exists and is identical to the source, the script skips it:
```
  ✓ ~/.vimrc is already up to date (matches config/vimrc)
```

If it differs:
```
  → ~/.zshrc differs from config/zshrc
  → backed up existing ~/.zshrc to ~/.shelly_backups/20260401_071500/.zshrc
  ● writing new ~/.zshrc...
  ✓ ~/.zshrc installed
```

---

### Step 4 — Vim (`04_vim.sh`)

| Check | Action |
|-------|--------|
| `~/.vim/autoload/plug.vim` exists | Download vim-plug via `curl -fLo` |
| `~/.vim/plugged/` has all expected plugin dirs | Run `vim +PlugInstall +qall` in headless mode |
| CoC extensions installed | Run `vim -c 'CocInstall -sync coc-tsserver coc-json coc-go coc-pyright' -c 'qall'` headless |

**Expected plugin directories** (17 plugins from your .vimrc):

```
auto-pairs  coc.nvim  fzf  fzf.vim  nerdtree
vim-go  vim-polyglot  vim-fugitive  vim-gitgutter
vim-code-dark  vim-airline  vim-airline-themes
vim-startify  vim-devicons  vim-ai  vimspector  gruvbox
```

The step verifies each directory exists after `PlugInstall`. Missing plugins are reported individually.

---

### Step 5 — nvm + Node.js (`05_nvm_node.sh`)

| Check | Action |
|-------|--------|
| `$NVM_DIR` is set and `nvm.sh` is sourceable | Source nvm from Homebrew prefix |
| `nvm ls` shows an installed version | `nvm install --lts` to install latest LTS |
| `nvm alias default` is set | `nvm alias default lts/*` |
| `node -v` and `npm -v` return successfully | Final verification |

---

## 5. Dotfile Contents

These are the exact files that ship in `config/`, captured from the current machine.

### `config/zshrc`

```zsh
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git z nvm colorize grc)

export NVM_HOMEBREW=$(brew --prefix nvm)
export ZSH_COLORIZE_TOOL=chroma
export ZSH_COLORIZE_STYLE=monokai
export ZSH_COLORIZE_CHROMA_FORMATTER=terminal256

source $ZSH/oh-my-zsh.sh

# Node.js version in right prompt
_node_prompt_info() {
  local node_version
  node_version=$(node -v 2>/dev/null) || return
  echo "%F{green}⬡ ${node_version%%.*}%f"
}
RPROMPT='$(_node_prompt_info)'

# Auto-switch node version based on .nvmrc, restore default on exit
_NVM_DEFAULT_VERSION=""
_nvm_auto_use() {
  local nvmrc="" dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/.nvmrc" ]] && { nvmrc="$dir/.nvmrc"; break; }
    dir="${dir:h}"
  done

  if [[ -n "$nvmrc" ]]; then
    local required installed current
    required="$(cat "$nvmrc" | tr -d '[:space:]')"
    installed="$(nvm version "$required" 2>/dev/null)"

    if [[ -z "$installed" || "$installed" == "N/A" ]]; then
      print -P "%F{yellow}⬡ Node ${required} (from .nvmrc) is not installed. Run: nvm install%f"
      return
    fi

    current="$(nvm current 2>/dev/null)"
    if [[ "$installed" != "$current" ]]; then
      [[ -z "$_NVM_DEFAULT_VERSION" ]] && _NVM_DEFAULT_VERSION="$current"
      nvm use >/dev/null 2>&1
      print -P "%F{green}⬡ Switched to Node ${installed}%f %F{white}(from .nvmrc)%f"
    fi
  elif [[ -n "$_NVM_DEFAULT_VERSION" ]]; then
    nvm use "$_NVM_DEFAULT_VERSION" >/dev/null 2>&1
    print -P "%F{cyan}⬡ Restored Node ${_NVM_DEFAULT_VERSION}%f"
    _NVM_DEFAULT_VERSION=""
  fi
}
add-zsh-hook chpwd _nvm_auto_use
_nvm_auto_use

alias cat=ccat
alias less=cless
alias ls='grc ls -p'
```

### `config/zshenv`

```zsh
. "$HOME/.cargo/env"
```

Note: cargo/env is sourced but Rust is **not** installed by Shelly (shell-only scope).
The script will wrap this source in an existence check so it doesn't error on a fresh machine:

```zsh
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
```

### `config/vimrc`

Full contents of the current `~/.vimrc` (178 lines) — copied verbatim.

### `config/gitconfig`

```ini
[user]
    name = {{GIT_NAME}}
    email = {{GIT_EMAIL}}
```

Placeholders are replaced interactively during `step_dotfiles`. If the target
`~/.gitconfig` already has `[user]` name/email set, the step keeps the existing
values and skips the prompt.

---

## 6. Edge Cases & Safety

| Scenario | Behavior |
|----------|----------|
| **Apple Silicon vs Intel** | Homebrew prefix is detected dynamically (`/opt/homebrew` vs `/usr/local`). PATH additions adapt. |
| **Homebrew already installed** | Skipped with `✓` message. No `brew update` is forced (avoid surprise breakage). |
| **Oh My Zsh already installed** | Directory check passes, skip clone. |
| **Dotfile is a symlink** | Resolve with `readlink`, compare target content. Backup the symlink itself. |
| **vim-plug PlugInstall partially complete** | The check counts directories in `~/.vim/plugged/` vs expected list. Only runs PlugInstall if any are missing. |
| **No internet** | Script detects network early (pings `github.com`) and fails fast with a clear message rather than hanging mid-step. |
| **`NVM_HOMEBREW` typo in current .zshrc** | The shipped `config/zshrc` fixes the existing typo (`NVM_HOMEBRE=W` → `NVM_HOMEBREW=`). |
| **User runs as root** | Refused. Script checks `$EUID` and exits if 0 (Homebrew refuses root, OMZ refuses root). |
| **ctrl-C mid-install** | Trap handler prints what completed so far and where to resume. Partial backups are kept. |

---

## 7. Execution Flow Diagram

```
install.sh
│
├── source lib/utils.sh          (colors, logging, backup functions)
│
├── Pre-flight checks
│   ├── Refuse root
│   ├── Detect architecture (arm64 / x86_64)
│   ├── Detect macOS version
│   └── Network connectivity check
│
├── source + run lib/01_homebrew.sh
│   └── step_homebrew
│       ├── install brew (if missing)
│       ├── install each formula
│       └── install each cask
│
├── source + run lib/02_ohmyzsh.sh
│   └── step_ohmyzsh
│       ├── clone omz (if missing)
│       └── verify default shell is zsh
│
├── source + run lib/03_dotfiles.sh
│   └── step_dotfiles
│       ├── for each dotfile: diff → backup → copy
│       └── gitconfig: prompt for name/email if needed
│
├── source + run lib/04_vim.sh
│   └── step_vim
│       ├── install vim-plug (if missing)
│       ├── PlugInstall (if plugins missing)
│       └── CocInstall (if extensions missing)
│
├── source + run lib/05_nvm_node.sh
│   └── step_nvm_node
│       ├── source nvm
│       ├── nvm install --lts (if no node)
│       └── nvm alias default
│
└── Print summary
```

---

## 8. `utils.sh` — Logging API

All step scripts use these functions (never raw `echo`):

```sh
log_step  "1" "5" "Homebrew"           # [STEP 1/5] Homebrew
log_ok    "brew is already installed"   # ✓ brew is already installed
log_work  "installing formula 'grc'"   # ● installing formula 'grc'...
log_fail  "brew install grc failed"    # ✗ brew install grc failed
log_info  "skipping — already exists"  # → skipping — already exists
log_warn  "NVM_HOMEBREW typo fixed"    # ⚠ NVM_HOMEBREW typo fixed
```

Color constants:
```sh
GREEN='\033[0;32m'  RED='\033[0;31m'  YELLOW='\033[0;33m'
CYAN='\033[0;36m'   BOLD='\033[1m'    RESET='\033[0m'
```

Backup helper:
```sh
backup_file() {
  local src="$1"
  local backup_dir="$HOME/.shelly_backups/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup_dir"
  cp -a "$src" "$backup_dir/"
  log_info "backed up $src to $backup_dir/$(basename "$src")"
}
```

---

## 9. How to Run

```sh
git clone <this-repo> ~/Code/shelly
cd ~/Code/shelly
chmod +x install.sh
./install.sh
```

Or on a truly fresh Mac (no git yet):

```sh
# Download as zip from GitHub, unzip, then:
cd shelly
chmod +x install.sh
./install.sh
```

The script requires **no arguments**. Everything is detected automatically.

---

## 10. What Shelly Does NOT Do

To keep scope tight and avoid surprises:

- Does **not** install GUI apps beyond Ghostty (no Arc, Docker, Cursor, etc.)
- Does **not** install language runtimes beyond Node.js via nvm
- Does **not** configure macOS system preferences (Dock, keyboard, Finder)
- Does **not** run `brew update` or `brew upgrade` on existing installs
- Does **not** touch `~/.ssh/` or any secrets/credentials
- Does **not** auto-commit or push anything to git
