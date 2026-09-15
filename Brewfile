# ============================================================================
# Homebrew Bundle
#
# Selectable groups (set by scripts/install.sh; default on if unset). Homebrew
# drops environment variables without a HOMEBREW_ prefix before it evaluates
# this file, so the group flags carry that prefix:
#   HOMEBREW_DOTFILES_BREW_CLI=1        core CLI, languages, fonts, taps they need
#   HOMEBREW_DOTFILES_BREW_APPS=1       GUI casks + Mac App Store
#   HOMEBREW_DOTFILES_BREW_WM=1         yabai / skhd / borders + related
#   HOMEBREW_DOTFILES_BREW_SKETCHYBAR=1 SketchyBar, lua, luarocks, audio helpers
#   HOMEBREW_DOTFILES_BREW_THEME=1      tinty + dark-notify (theme engine, see configs/theme/)
# ============================================================================

cli   = ENV.fetch("HOMEBREW_DOTFILES_BREW_CLI",        "1") == "1"
apps  = ENV.fetch("HOMEBREW_DOTFILES_BREW_APPS",       "1") == "1"
wm    = ENV.fetch("HOMEBREW_DOTFILES_BREW_WM",         "1") == "1"
sbar  = ENV.fetch("HOMEBREW_DOTFILES_BREW_SKETCHYBAR", "1") == "1"
theme = ENV.fetch("HOMEBREW_DOTFILES_BREW_THEME",      "1") == "1"

# ============================================================================
# Taps
# ============================================================================
#
# Homebrew 6.0+ refuses to load formulae/casks from non-official taps unless
# they are trusted. `trusted: true` registers that trust from the Brewfile
# itself (applied before any formula loads), so `brew bundle` stays
# non-interactive — no manual `brew trust` step on a fresh machine.

tap "asmvik/formulae", trusted: true if wm
tap "cormacrelf/tap", trusted: true if theme
tap "docker/tap", trusted: true if cli || apps
tap "felixkratz/formulae", trusted: true if sbar || wm
tap "jesseduffield/lazydocker", trusted: true if cli
tap "jesseduffield/lazygit", trusted: true if cli
tap "lerd-env/lerd", trusted: true if cli
tap "stripe/stripe-cli", trusted: true if cli
tap "tinted-theming/tinted", trusted: true if theme

# ============================================================================
# Core System & CLI Tools
# ============================================================================

# Shell and Utilities
brew "bash" if cli
brew "bats-core" if cli
brew "gum" if cli
brew "shellcheck" if cli
brew "shfmt" if cli
brew "vivid" if cli
brew "zsh" if cli
brew "zsh-autosuggestions" if cli
brew "zsh-completions" if cli
brew "zsh-syntax-highlighting" if cli

# Theme Engine (see configs/theme/)
brew "dark-notify" if theme
brew "tinty" if theme

# GNU Core Utilities
brew "coreutils" if cli
brew "findutils" if cli
brew "gnu-sed" if cli
brew "grep" if cli
brew "less" if cli

# Modern CLI Replacements
brew "bat" if cli
brew "btop" if cli
brew "eza" if cli
brew "fastfetch" if cli
brew "fd" if cli
brew "fzf" if cli
brew "htop" if cli
brew "ripgrep" if cli
brew "yazi" if cli
brew "zoxide" if cli

# File and Data Tools
brew "jq" if cli
brew "tmux" if cli
brew "trash" if cli
brew "tree" if cli
brew "unzip" if cli
brew "yq" if cli
cask "rar" if cli

# Network Tools
brew "curl" if cli
brew "nmap" if cli
brew "wget" if cli

# Media & Audio Tools
brew "nowplaying-cli" if sbar
brew "switchaudio-osx" if sbar
cask "focusrite-control-2" if apps

# ============================================================================
# Version Control & Development Core
# ============================================================================

brew "gh" if cli
brew "git" if cli
brew "git-delta" if cli
brew "lazygit" if cli
brew "tuicr" if cli

# Security Tools
brew "gnupg" if cli
brew "nss" if cli
brew "openssh" if cli
cask "1password-cli" if cli

# ============================================================================
# Window Management & macOS Enhancements
# ============================================================================

brew "borders" if wm
brew "mas" if cli
brew "skhd" if wm
brew "sketchybar" if sbar
brew "yabai" if wm
cask "linearmouse" if wm
cask "logitech-g-hub" if apps

# ============================================================================
# Programming Languages & Runtimes
# ============================================================================

brew "lua" if sbar
brew "luarocks" if sbar
brew "python" if cli
brew "uv" if cli

# ============================================================================
# Development Tools & IDEs
# ============================================================================

# Editors
brew "neovim" if cli
cask "claude" if apps
cask "claude-code" if apps
cask "cursor" if apps
cask "jetbrains-toolbox" if apps
cask "visual-studio-code" if apps

# Development Services
brew "cloudflared" if cli
brew "lerd" if cli
brew "stripe" if cli
cask "bruno" if apps

# Git Clients
cask "gitkraken" if apps
cask "tower" if apps

# ============================================================================
# DevOps & Infrastructure
# ============================================================================

brew "lazydocker" if cli
cask "docker-desktop" if apps
cask "sbx" if apps

# ============================================================================
# Database Management
# ============================================================================

cask "redis-insight" if apps
cask "tableplus" if apps

# ============================================================================
# Applications
# ============================================================================

# Security & System
brew "mole" if cli
brew "pinentry-mac" if cli
cask "1password" if apps
cask "little-snitch" if apps
cask "mullvad-vpn" if apps
cask "raycast" if apps

# Terminals
cask "warp" if apps

# Browsers
cask "firefox" if apps

# Communication
cask "discord" if apps
cask "slack" if apps
cask "zoom" if apps

# Design & Media
cask "figma" if apps
cask "mactex-no-gui" if apps
cask "spotify" if apps

# Project Management
cask "linear" if apps

# ============================================================================
# Fonts
# ============================================================================

cask "font-jetbrains-mono" if cli
cask "font-jetbrains-mono-nerd-font" if cli
cask "font-sf-mono" if cli
cask "font-sf-pro" if cli
cask "sf-symbols" if cli

# ============================================================================
# Mac App Store
# ============================================================================

mas "1Password for Safari", id: 1569813296 if apps
mas "uBlock Origin Lite", id: 6745342698 if apps
mas "Xcode", id: 497799835 if apps
