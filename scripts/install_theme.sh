#!/usr/bin/env bash
# Theme engine setup: sync tinty, render roost templates, apply the chosen
# family, and install the dark-notify LaunchAgent for auto light/dark.
# Idempotent: re-running re-syncs, re-renders, re-applies, and reloads the agent.

set -euo pipefail

scrDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=global_fn.sh
source "${scrDir}/global_fn.sh"
enable_error_trap

print_log -sec "theme" -info "Starting" "Theme setup"

for tool in tinty dark-notify; do
    if ! command_exists "${tool}"; then
        print_log -sec "theme" -err "Missing" "${tool} not found - install the theme brew group first"
        exit 1
    fi
done

theme_bin="${HOME}/.local/bin/theme"
if [[ ! -x "${theme_bin}" ]]; then
    print_log -sec "theme" -err "Missing" "${theme_bin} not linked - run the theme configs step (install.theme.conf.yaml) first"
    exit 1
fi

print_log -sec "theme" -info "tinty" "Syncing schemes and upstream templates..."
with_retry 3 run_spin "tinty sync" tinty sync --quiet

print_log -sec "theme" -info "tinty" "Rendering roost templates..."
"${theme_bin}" rebuild

# bat now uses its builtin base16 theme; drop any cache built from the old vendored tmThemes.
if command_exists bat; then
    bat cache --clear >/dev/null 2>&1 || true
fi

state_file="${XDG_STATE_HOME:-${HOME}/.local/state}/roost/theme/family"
if [[ -r "${state_file}" ]]; then
    print_log -sec "theme" -info "Apply" "Re-applying family $(cat "${state_file}")..."
    "${theme_bin}" sync
else
    family="${DOTFILES_THEME_FAMILY:-catppuccin}"
    print_log -sec "theme" -info "Apply" "Applying default family ${family}..."
    "${theme_bin}" set "${family}"
fi

label="com.roost.theme-sync"
plist_src="${configDir}/theme/launchd/${label}.plist"
plist_dst="${HOME}/Library/LaunchAgents/${label}.plist"
domain="gui/$(id -u)"

print_log -sec "theme" -info "Service" "Installing ${label} (dark-notify -> theme sync)..."
mkdir -p "${HOME}/Library/LaunchAgents"
cp -f "${plist_src}" "${plist_dst}"
launchctl bootout "${domain}/${label}" 2>/dev/null || true
if launchctl bootstrap "${domain}" "${plist_dst}"; then
    print_log -sec "theme" -g "Started" "${label}"
else
    print_log -sec "theme" -warn "Failed" "Could not start ${label} - try: launchctl bootstrap ${domain} ${plist_dst}"
fi

print_log -sec "theme" -g "Complete" "Theme setup completed"
print_log -sec "theme" -info "Next" "In Warp: Settings > Appearance > choose the 'tinty' theme (or set it for both modes under Sync with OS)"
print_log -sec "theme" -info "Next" "In Claude Code: run /theme and pick Tinty"
