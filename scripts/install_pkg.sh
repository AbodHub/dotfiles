#!/usr/bin/env bash
# Install from the root Brewfile (groups selected via DOTFILES_BREW_*).

set -euo pipefail

scrDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=global_fn.sh
source "${scrDir}/global_fn.sh"
enable_error_trap

print_log -sec "install-pkg" -info "Starting" "Package installation via Homebrew Bundle"

if ! homebrew_installed; then
    print_log -sec "install-pkg" -err "Missing" "Homebrew not found — run the prerequisites step first"
    exit 1
fi

# DOTFILES_BREWFILE is a filtered Brewfile from the interactive per-package
# picker; fall back to the full repo Brewfile for flag-driven / non-interactive runs.
brewfile="${DOTFILES_BREWFILE:-${repoDir}/Brewfile}"
if [[ ! -f "${brewfile}" ]]; then
    print_log -sec "install-pkg" -err "Missing" "Brewfile not found at ${brewfile}"
    exit 1
fi
[[ -n "${DOTFILES_BREWFILE:-}" ]] && print_log -sec "install-pkg" -info "Selection" "Installing a custom package selection"

# Default: all groups on when invoked directly
export DOTFILES_BREW_CLI="${DOTFILES_BREW_CLI:-1}"
export DOTFILES_BREW_APPS="${DOTFILES_BREW_APPS:-1}"
export DOTFILES_BREW_WM="${DOTFILES_BREW_WM:-1}"
export DOTFILES_BREW_SKETCHYBAR="${DOTFILES_BREW_SKETCHYBAR:-1}"
export DOTFILES_BREW_THEME="${DOTFILES_BREW_THEME:-1}"

print_log -sec "install-pkg" -info "Groups" "cli=${DOTFILES_BREW_CLI} apps=${DOTFILES_BREW_APPS} wm=${DOTFILES_BREW_WM} sketchybar=${DOTFILES_BREW_SKETCHYBAR} theme=${DOTFILES_BREW_THEME}"

if ! run_brewfile "${brewfile}"; then
    print_log -sec "install-pkg" -warn "Partial" "Some packages may have failed — re-run: brew bundle install --file=${brewfile}"
fi

# Skip the fixed-list check when a custom per-package selection is in play:
# the user may have deliberately dropped one of these, so "missing" would be noise.
if [[ -n "${DOTFILES_BREWFILE:-}" ]]; then
    print_log -sec "install-pkg" -info "Verification" "Skipped (custom package selection)"
else
    print_log -sec "install-pkg" -info "Verification" "Checking critical commands for selected groups..."

    critical=()
    [[ "${DOTFILES_BREW_CLI}" == "1" ]] && critical+=("git" "nvim" "zsh")
    [[ "${DOTFILES_BREW_WM}" == "1" ]] && critical+=("yabai" "skhd")
    [[ "${DOTFILES_BREW_SKETCHYBAR}" == "1" ]] && critical+=("sketchybar" "lua" "luarocks")
    [[ "${DOTFILES_BREW_THEME}" == "1" ]] && critical+=("tinty" "dark-notify")

    missing=()
    for cmd in "${critical[@]}"; do
        if command_exists "${cmd}"; then
            print_log -sec "install-pkg" -g "ok" "${cmd}"
        else
            print_log -sec "install-pkg" -r "missing" "${cmd}"
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_log -sec "install-pkg" -warn "PATH" "Some tools are missing from PATH; a new shell may be required"
    fi
fi

print_log -sec "install-pkg" -g "Complete" "Package installation completed"
