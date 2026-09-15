#!/usr/bin/env bash
# macOS dotfiles installer — component-based.

set -euo pipefail

scrDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=global_fn.sh
source "${scrDir}/global_fn.sh"
# shellcheck source=brewfile.sh
source "${scrDir}/brewfile.sh"

usage() {
    cat <<EOF
Usage: $0 [options]

Components (select at least one, or use interactive mode on a TTY):
  --packages           Install from the Brewfile (see brew groups below)
  --shell              Set up Oh My Zsh, Powerlevel10k, nvm
  --configs            Link base dotfiles (git / shell / editors) via Dotbot
  --wm-configs         Link window-manager configs (yabai / skhd / borders)
  --sketchybar-configs Link the SketchyBar config
  --wm-services        Start window-manager services (yabai / skhd / borders)
  --sketchybar-service Start the SketchyBar service
  --services           Start both WM and SketchyBar services
  --macos              Apply macOS defaults (scripts/macos.sh)
  --all                Enable every component above (all brew groups)

Brew groups (only apply with --packages / --all / interactive packages):
  --brew-cli / --no-brew-cli               Core CLI, fonts (default: on)
  --brew-apps / --no-brew-apps             GUI casks + Mac App Store
  --brew-wm / --no-brew-wm                 yabai / skhd / borders
  --brew-sketchybar / --no-brew-sketchybar SketchyBar, lua, luarocks, audio helpers

Maintenance:
  --reset-yabai   Reinstall the yabai scripting addition (after a yabai upgrade)

Behavior:
  --yes, -y       Accept defaults / skip yes-no prompts where applicable
  --dry-run, -n   Print what would run without making changes
  -h, --help      Show this help

With no component flags:
  - Interactive TTY  → guided, feature-first picker (with per-package pruning)
  - Non-interactive  → error (pass flags or --all)

Examples:
  $0                                  # interactive picker
  $0 --packages --shell --configs
  $0 --packages --no-brew-apps --brew-sketchybar --no-brew-wm
  $0 --brew-wm --wm-configs --wm-services
  $0 --all --dry-run
  $0 --reset-yabai
EOF
}

flg_Packages=0
flg_Shell=0
flg_Configs=0
flg_WmConfigs=0
flg_WmServices=0
flg_SbarConfigs=0
flg_SbarService=0
flg_Macos=0
flg_DryRun=0
flg_AnyComponent=0
flg_ResetYabai=0

# Hostname collected by the interactive picker (only when macOS defaults are
# chosen). Empty means "leave the hostname unchanged"; the flag-driven path
# still honors a COMPUTER_NAME set in the environment.
hostName=""

# Brew subbundles: -1 = unset (derive from context), 0 = off, 1 = on
brew_cli=-1
brew_apps=-1
brew_wm=-1
brew_sbar=-1

# Whether each feature's core package survived per-package pruning (gates the
# config/service follow-ups in the interactive picker).
wm_core_kept=1
sbar_core_kept=1

mark_component() {
    flg_AnyComponent=1
}

reset_flags() {
    flg_Packages=0
    flg_Shell=0
    flg_Configs=0
    flg_WmConfigs=0
    flg_WmServices=0
    flg_SbarConfigs=0
    flg_SbarService=0
    flg_Macos=0
    flg_DryRun=0
    flg_AnyComponent=0
    flg_ResetYabai=0
    hostName=""
    brew_cli=-1
    brew_apps=-1
    brew_wm=-1
    brew_sbar=-1
    wm_core_kept=1
    sbar_core_kept=1
    unset use_default 2>/dev/null || true
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --packages | --pkg)
                flg_Packages=1
                mark_component
                shift
                ;;
            --shell)
                flg_Shell=1
                mark_component
                shift
                ;;
            --configs)
                flg_Configs=1
                mark_component
                shift
                ;;
            --wm-configs)
                flg_WmConfigs=1
                mark_component
                shift
                ;;
            --sketchybar-configs | --sbar-configs)
                flg_SbarConfigs=1
                mark_component
                shift
                ;;
            --wm-services)
                flg_WmServices=1
                mark_component
                shift
                ;;
            --sketchybar-service | --sbar-service)
                flg_SbarService=1
                mark_component
                shift
                ;;
            --services)
                flg_WmServices=1
                flg_SbarService=1
                mark_component
                shift
                ;;
            --macos)
                flg_Macos=1
                mark_component
                shift
                ;;
            --reset-yabai)
                flg_ResetYabai=1
                shift
                ;;
            --brew-cli)
                brew_cli=1
                mark_component
                shift
                ;;
            --no-brew-cli)
                brew_cli=0
                shift
                ;;
            --brew-apps)
                brew_apps=1
                mark_component
                shift
                ;;
            --no-brew-apps)
                brew_apps=0
                shift
                ;;
            --brew-wm)
                brew_wm=1
                mark_component
                shift
                ;;
            --no-brew-wm)
                brew_wm=0
                shift
                ;;
            --brew-sketchybar | --brew-sbar)
                brew_sbar=1
                mark_component
                shift
                ;;
            --no-brew-sketchybar | --no-brew-sbar)
                brew_sbar=0
                shift
                ;;
            --all)
                flg_Packages=1
                flg_Shell=1
                flg_Configs=1
                flg_WmConfigs=1
                flg_WmServices=1
                flg_SbarConfigs=1
                flg_SbarService=1
                flg_Macos=1
                brew_cli=1
                brew_apps=1
                brew_wm=1
                brew_sbar=1
                mark_component
                shift
                ;;
            --yes | -y)
                export use_default="--yes"
                shift
                ;;
            --dry-run | -n)
                flg_DryRun=1
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                print_log -err "Usage" "Unrecognized argument: $1"
                usage
                exit 1
                ;;
        esac
    done
}

picker_basic() {
    # Plain-prompt fallback (no gum). Same feature-first order as gum_picker,
    # minus per-package pruning (that needs gum's multi-select).
    print_log -b "roost" "Choose what to set up (defaults in brackets)"
    echo ""

    if prompt_yes_no "CLI tools & fonts" default_yes; then
        brew_cli=1
        flg_Packages=1
    fi
    if prompt_yes_no "GUI apps" default_no; then
        brew_apps=1
        flg_Packages=1
    fi
    prompt_yes_no "Shell environment (Oh My Zsh / Powerlevel10k / nvm)" default_yes && flg_Shell=1
    prompt_yes_no "Base dotfiles (git / shell / editors)" default_yes && flg_Configs=1

    if prompt_yes_no "Window management (yabai / skhd / borders)" default_no; then
        brew_wm=1
        flg_Packages=1
        prompt_yes_no "  Link window-manager configs?" default_yes && flg_WmConfigs=1
        prompt_yes_no "  Start the window-manager services now?" default_yes && flg_WmServices=1
    fi
    if prompt_yes_no "SketchyBar (status bar)" default_no; then
        brew_sbar=1
        flg_Packages=1
        prompt_yes_no "  Link the SketchyBar config?" default_yes && flg_SbarConfigs=1
        prompt_yes_no "  Start the SketchyBar service now?" default_yes && flg_SbarService=1
    fi
    if prompt_yes_no "Apply macOS system defaults" default_no; then
        flg_Macos=1
        hostName="$(prompt_input "Computer hostname (blank to keep current)" "")"
    fi

    # Any brew group not chosen is explicitly off (clean 0/1 picker output).
    [[ "${brew_cli}" -lt 0 ]] && brew_cli=0
    [[ "${brew_apps}" -lt 0 ]] && brew_apps=0
    [[ "${brew_wm}" -lt 0 ]] && brew_wm=0
    [[ "${brew_sbar}" -lt 0 ]] && brew_sbar=0
    return 0
}

gum_picker() {
    # Feature-first: one coherent choice per feature. Configs/services are
    # dependency-gated follow-ups owned by their feature, not separate top-level
    # questions. gum --selected is comma-separated, so labels carry no commas.
    local -a features=(
        "CLI tools & fonts"
        "GUI apps"
        "Shell environment (Oh My Zsh / Powerlevel10k / nvm)"
        "Base dotfiles (git / shell / editors)"
        "Window management (yabai + skhd + borders)"
        "SketchyBar (status bar)"
        "macOS system defaults"
    )
    local chosen
    chosen="$(printf '%s\n' "${features[@]}" | gum choose --no-limit --show-help \
        --header="What should roost set up? (pick any)" \
        --selected="CLI tools & fonts,Shell environment (Oh My Zsh / Powerlevel10k / nvm),Base dotfiles (git / shell / editors)")" || chosen=""

    grep -q "^CLI tools" <<<"${chosen}" && {
        brew_cli=1
        flg_Packages=1
    }
    grep -q "^GUI apps" <<<"${chosen}" && {
        brew_apps=1
        flg_Packages=1
    }
    grep -q "^Shell environment" <<<"${chosen}" && flg_Shell=1
    grep -q "^Base dotfiles" <<<"${chosen}" && flg_Configs=1
    grep -q "^Window management" <<<"${chosen}" && {
        brew_wm=1
        flg_Packages=1
    }
    grep -q "^SketchyBar" <<<"${chosen}" && {
        brew_sbar=1
        flg_Packages=1
    }
    grep -q "^macOS system defaults" <<<"${chosen}" && flg_Macos=1

    # A brew group not chosen above is explicitly off (clean 0/1 picker output).
    [[ "${brew_cli}" -lt 0 ]] && brew_cli=0
    [[ "${brew_apps}" -lt 0 ]] && brew_apps=0
    [[ "${brew_wm}" -lt 0 ]] && brew_wm=0
    [[ "${brew_sbar}" -lt 0 ]] && brew_sbar=0

    # Prune individual packages for the chosen package features.
    if [[ "${flg_Packages}" -eq 1 ]]; then
        select_packages
    fi

    # Dependency-gated follow-ups. yabai and sketchybar are each a feature's core;
    # if pruning dropped the core, its configs/services are moot, so we skip them.
    if [[ "${brew_wm}" -eq 1 ]]; then
        if [[ "${wm_core_kept}" -eq 1 ]]; then
            prompt_yes_no "Link window-manager configs (yabai / skhd / borders)?" default_yes && flg_WmConfigs=1
            prompt_yes_no "Start the window-manager services now?" default_yes && flg_WmServices=1
        else
            print_log -y "Skip" "yabai deselected — skipping window-manager configs and services"
        fi
    fi
    if [[ "${brew_sbar}" -eq 1 ]]; then
        if [[ "${sbar_core_kept}" -eq 1 ]]; then
            prompt_yes_no "Link the SketchyBar config?" default_yes && flg_SbarConfigs=1
            prompt_yes_no "Start the SketchyBar service now?" default_yes && flg_SbarService=1
        else
            print_log -y "Skip" "sketchybar deselected — skipping its config and service"
        fi
    fi

    # Hostname is a macOS default, so it's only offered when that feature is on.
    if [[ "${flg_Macos}" -eq 1 ]]; then
        hostName="$(prompt_input "Computer hostname (blank to keep current)" "")"
    fi
    return 0
}

select_packages() {
    # Interactive per-package pruning (gum only). Writes a filtered Brewfile to a
    # temp path and exports DOTFILES_BREWFILE. Records whether each feature's core
    # package (yabai / sketchybar) survived pruning, so gum_picker can gate the
    # config/service follow-ups on it.
    wm_core_kept=1
    sbar_core_kept=1

    local orig="${repoDir}/Brewfile"
    [[ -f "${orig}" ]] || return 0

    local keepfile tmp
    keepfile="$(mktemp -t roost-keep.XXXXXX)"
    tmp="$(mktemp -t roost-brewfile.XXXXXX)"
    : >"${keepfile}"

    local -a groups=()
    [[ "${brew_cli}" -eq 1 ]] && groups+=(cli)
    [[ "${brew_apps}" -eq 1 ]] && groups+=(apps)
    [[ "${brew_wm}" -eq 1 ]] && groups+=(wm)
    [[ "${brew_sbar}" -eq 1 ]] && groups+=(sbar)

    local group
    for group in "${groups[@]}"; do
        _select_group_packages "${group}" "${orig}" "${keepfile}"
    done

    if [[ "${brew_wm}" -eq 1 ]] && ! grep -qx "brew:yabai" "${keepfile}"; then
        wm_core_kept=0
    fi
    if [[ "${brew_sbar}" -eq 1 ]] && ! grep -qx "brew:sketchybar" "${keepfile}"; then
        sbar_core_kept=0
    fi

    brewfile_generate "${orig}" "${brew_cli}" "${brew_apps}" "${brew_wm}" "${brew_sbar}" "${brew_theme:-0}" \
        "${keepfile}" >"${tmp}"
    rm -f "${keepfile}"
    export DOTFILES_BREWFILE="${tmp}"
    print_log -info "Packages" "Using your custom package selection"
}

_select_group_packages() {
    local group=$1 orig=$2 keepfile=$3
    # Parallel indexed arrays (labels[i] ↔ keys[i]). No associative array here:
    # macOS ships bash 3.2, where `local -A` is a hard error.
    local -a labels=() keys=()
    local type name spec label

    # spec is unused here (only the generator needs it) but is part of the shared TSV.
    # shellcheck disable=SC2034
    while IFS=$'\t' read -r type name spec; do
        label="${name}  [${type}]"
        labels+=("${label}")
        keys+=("${type}:${name}")
    done < <(brewfile_candidates "${orig}" "${group}")

    [[ ${#labels[@]} -eq 0 ]] && return 0

    local preselect
    preselect="$(
        IFS=,
        printf '%s' "${labels[*]}"
    )"

    local chosen keep_all=0
    chosen="$(printf '%s\n' "${labels[@]}" | gum choose --no-limit --height 20 --show-help \
        --header="${group} packages (keep the ones you want)" \
        --selected="${preselect}")" || keep_all=1

    local i
    if [[ "${keep_all}" -eq 1 ]]; then
        # gum exited non-zero (cancelled / interrupted) — keep the pre-checked
        # defaults rather than silently dropping every package in the group.
        print_log -y "Kept" "${group}: selection cancelled — keeping all packages"
        for i in "${!labels[@]}"; do
            printf '%s\n' "${keys[$i]}" >>"${keepfile}"
        done
        return 0
    fi

    for i in "${!labels[@]}"; do
        if grep -Fxq "${labels[$i]}" <<<"${chosen}"; then
            printf '%s\n' "${keys[$i]}" >>"${keepfile}"
        fi
    done
}

run_interactive() {
    if ui_rich; then
        gum_picker
    else
        picker_basic
    fi

    # If the picker was dismissed with nothing chosen, don't march on to a
    # no-op "success" — say so and stop.
    local total=$((flg_Packages + flg_Shell + flg_Configs + flg_WmConfigs + \
        flg_WmServices + flg_SbarConfigs + flg_SbarService + flg_Macos))
    if [[ "${total}" -eq 0 ]]; then
        print_log -warn "Nothing selected" "No features chosen — nothing to do"
        exit 0
    fi
    flg_AnyComponent=1
}

select_gpg_key() {
    # Echo the chosen GPG key id (or empty). Lists local secret keys when gpg
    # is available; otherwise falls back to a manual key-id prompt.
    if ! command_exists gpg; then
        prompt_input "GPG signing key ID" ""
        return 0
    fi

    local keys
    keys="$(gpg --list-secret-keys --keyid-format=long 2>/dev/null |
        awk '/^sec/ { split($2, a, "/"); id = a[2] }
             /^uid/ { sub(/^uid[[:space:]]+/, ""); print id "  " $0 }')"

    if [[ -z "${keys}" ]]; then
        prompt_input "GPG signing key ID (no secret keys found)" ""
        return 0
    fi

    if ui_rich; then
        local pick
        pick="$(printf '%s\n' "${keys}" | gum choose --header="Select GPG signing key")" || true
        printf '%s' "${pick%% *}"
    else
        print_log -info "GPG keys" "Available secret keys:"
        printf '%s\n' "${keys}" >&2
        prompt_input "GPG signing key ID (copy from the list above)" ""
    fi
}

setup_git_identity() {
    # Personalize configs/git/gitconfig before Dotbot links it. Forkers own
    # their fork, so writing identity into the tracked file is intended. The
    # block is appended so tracked sections (init, include) survive.
    local gc="${configDir}/git/gitconfig"

    if grep -q '^\[user\]' "${gc}" 2>/dev/null; then
        print_log -y "Skip" "git identity already set in ${gc}"
        return 0
    fi
    if [[ "${use_default:-}" == "--yes" ]] || ! is_tty; then
        print_log -warn "Git identity" "Non-interactive — add a [user] section to ${gc} by hand"
        return 0
    fi

    local name email
    name="$(prompt_input "Git author name" "")"
    email="$(prompt_input "Git author email" "")"
    if [[ -z "${name}" || -z "${email}" ]]; then
        print_log -warn "Git identity" "Name/email blank — add a [user] section to ${gc} later"
        return 0
    fi

    local key="" gpgprog=""
    if prompt_yes_no "Enable GPG commit signing?" default_no; then
        key="$(select_gpg_key)"
        gpgprog="$(command -v gpg || true)"
    fi

    {
        echo "[user]"
        echo "	name = ${name}"
        echo "	email = ${email}"
        [[ -n "${key}" ]] && echo "	signingKey = ${key}"
        if [[ -n "${key}" ]]; then
            echo "[commit]"
            echo "	gpgSign = true"
            [[ -n "${gpgprog}" ]] && printf '[gpg]\n\tprogram = %s\n' "${gpgprog}"
        fi
    } >>"${gc}"

    print_log -g "Git identity" "Wrote ${gc}"
}

resolve_brew_groups() {
    local any_group_on=0
    [[ "${brew_cli}" -eq 1 || "${brew_apps}" -eq 1 || "${brew_wm}" -eq 1 || "${brew_sbar}" -eq 1 ]] &&
        any_group_on=1

    # An explicitly-enabled brew group implies installing packages.
    [[ "${any_group_on}" -eq 1 ]] && flg_Packages=1

    if [[ "${flg_Packages}" -eq 1 ]]; then
        # If the user named specific groups, unset groups stay off; if they asked
        # for packages without naming any group, unset groups default on.
        local unset_default=1
        [[ "${any_group_on}" -eq 1 ]] && unset_default=0
        [[ "${brew_cli}" -lt 0 ]] && brew_cli=${unset_default}
        [[ "${brew_apps}" -lt 0 ]] && brew_apps=${unset_default}
        [[ "${brew_wm}" -lt 0 ]] && brew_wm=${unset_default}
        [[ "${brew_sbar}" -lt 0 ]] && brew_sbar=${unset_default}
    else
        brew_cli=0
        brew_apps=0
        brew_wm=0
        brew_sbar=0
    fi
    return 0
}

validate_selection() {
    if [[ "${flg_Packages}" -eq 1 && "${brew_cli}" -eq 0 && "${brew_apps}" -eq 0 && "${brew_wm}" -eq 0 && "${brew_sbar}" -eq 0 ]]; then
        print_log -err "Brewfile" "Packages selected but all brew groups are off"
        return 1
    fi

    # Dependency warnings — permissive (Q3): linking dotfiles or starting a
    # guarded service without its package is harmless, and you may already have
    # the tool installed. Warn, don't block.
    [[ "${flg_WmConfigs}" -eq 1 && "${brew_wm}" -ne 1 ]] &&
        print_log -warn "Deps" "Linking window-manager configs, but no WM packages are selected"
    [[ "${flg_WmServices}" -eq 1 && "${brew_wm}" -ne 1 ]] &&
        print_log -warn "Deps" "Starting window-manager services, but no WM packages are selected"
    [[ "${flg_SbarConfigs}" -eq 1 && "${brew_sbar}" -ne 1 ]] &&
        print_log -warn "Deps" "Linking the SketchyBar config, but no SketchyBar packages are selected"
    [[ "${flg_SbarService}" -eq 1 && "${brew_sbar}" -ne 1 ]] &&
        print_log -warn "Deps" "Starting the SketchyBar service, but no SketchyBar packages are selected"
    return 0
}

describe_plan() {
    print_log -y "DRY RUN" "no changes will be made"
    [[ "${need_pre}" -eq 1 ]] && print_log -info "Pre" "Would run install_pre.sh (Xcode CLT, Homebrew)"
    if [[ "${flg_Packages}" -eq 1 ]]; then
        print_log -info "Packages" "Would brew bundle Brewfile (cli=${brew_cli} apps=${brew_apps} wm=${brew_wm} sketchybar=${brew_sbar})"
        [[ "${brew_sbar}" -eq 1 ]] && print_log -info "SketchyBar" "Would run install_sketchybar.sh"
    fi
    [[ "${flg_Shell}" -eq 1 ]] && print_log -info "Shell" "Would run install_shell.sh"
    [[ "${flg_Configs}" -eq 1 ]] && print_log -info "Base dotfiles" "Would link install.conf.yaml"
    [[ "${flg_WmConfigs}" -eq 1 ]] && print_log -info "WM configs" "Would link install.wm.conf.yaml (yabai / skhd / borders)"
    [[ "${flg_SbarConfigs}" -eq 1 ]] && print_log -info "SketchyBar config" "Would link install.sketchybar.conf.yaml"
    if [[ "${flg_Macos}" -eq 1 ]]; then
        local host="${hostName:-${COMPUTER_NAME:-}}"
        if [[ -n "${host}" ]]; then
            print_log -info "macOS" "Would run scripts/macos.sh (hostname → ${host})"
        else
            print_log -info "macOS" "Would run scripts/macos.sh (hostname unchanged)"
        fi
    fi
    command_exists mo && print_log -info "Touch ID" "Would offer 'mo touchid enable' (sudo via Touch ID)"
    if [[ "${flg_WmServices}" -eq 1 || "${flg_SbarService}" -eq 1 ]]; then
        print_log -info "Services" "Would start services (wm=${flg_WmServices} sketchybar=${flg_SbarService})"
    fi
    return 0
}

maybe_enable_touchid() {
    # mole ships the `mo` CLI; `mo touchid enable` wires up Touch ID for sudo
    # (via a pam sudo_local drop-in). Only offer it interactively — it changes a
    # security setting and prompts for the admin password, so never unattended.
    command_exists mo || return 0
    { [[ "${use_default:-}" == "--yes" ]] || ! is_tty; } && return 0

    if prompt_yes_no "Enable Touch ID for sudo (mo touchid enable)?" default_yes; then
        print_log -info "Touch ID" "Enabling Touch ID for sudo..."
        if mo touchid enable; then
            print_log -g "Touch ID" "Enabled — sudo now accepts your fingerprint"
        else
            print_log -warn "Touch ID" "'mo touchid enable' failed — run it yourself later"
        fi
    fi
}

resolve_link_conflicts() {
    # Dotbot's `relink: true` replaces stray symlinks but refuses to clobber a
    # real file/dir (that needs `force: true`, which silently destroys data). So
    # before linking a Dotbot config, find its targets that already exist as real
    # files — e.g. the ~/.zshrc that Oh My Zsh writes in the shell step — and,
    # with the user's OK, back them up and move them aside so linking succeeds.
    # Returns non-zero (caller skips the link step) if the user declines.
    local conf=$1
    local -a conflicts=()
    local key path

    # Pull the link targets: indented "~/...:" keys under the `- link:` block.
    # (The `- create:` list uses "- ~/..." — a leading dash — so it won't match.)
    # awk, not grep: the parse must not depend on which grep variant is on PATH.
    while IFS= read -r key; do
        key="${key%:}"
        path="${key/#\~/${HOME}}"
        if [[ -e "${path}" && ! -L "${path}" ]]; then
            conflicts+=("${path}")
        fi
    done < <(awk '
        /^-[[:space:]]+link:/ { inlink = 1; next }
        /^-[[:space:]]/       { inlink = 0 }
        inlink {
            line = $0; sub(/#.*/, "", line)
            if (match(line, /^[[:space:]]+~[^:]+:/)) {
                key = substr(line, RSTART, RLENGTH)
                gsub(/[[:space:]]/, "", key)
                print key
            }
        }
    ' "${conf}")

    [[ ${#conflicts[@]} -eq 0 ]] && return 0

    print_log -warn "Conflicts" "These already exist as real files and would block linking:"
    local c
    for c in "${conflicts[@]}"; do
        printf '      %s\n' "${c}" >&2
    done

    if ! prompt_yes_no "Back them up and replace with symlinks?" default_yes; then
        print_log -y "Kept" "Existing files left in place — skipping this link step"
        return 1
    fi

    local backup_dir
    backup_dir="${repoDir}/backups/$(date +'%Y%m%d_%H%M%S')"
    mkdir -p "${backup_dir}"
    for c in "${conflicts[@]}"; do
        mv "${c}" "${backup_dir}/"
    done
    print_log -g "Backup" "Moved ${#conflicts[@]} file(s) to ${backup_dir}"
    return 0
}

main() {
    enable_error_trap
    trap 'rm -f "${DOTFILES_BREWFILE:-}" 2>/dev/null || true' EXIT
    parse_args "$@"

    if [[ "${flg_ResetYabai}" -eq 1 ]]; then
        exec "${scrDir}/reset_yabai.sh"
    fi

    local pre_done=0
    if [[ "${flg_AnyComponent}" -eq 0 ]]; then
        if is_tty; then
            print_section "roost — macOS setup"
            # Install prerequisites (Homebrew + gum) BEFORE the picker so the
            # rich picker is available on first run. Skip on --dry-run.
            if [[ "${flg_DryRun}" -eq 0 ]]; then
                "${scrDir}/install_pre.sh"
                pre_done=1
                # install_pre.sh installed brew + gum in a child process, so its
                # PATH change didn't reach us. Pick brew up here so the picker
                # below gets the rich (gum) UI on a first run.
                ensure_brew_on_path
            fi
            run_interactive
        else
            print_log -err "Non-interactive" "No component flags given. Pass --all or specific components (see --help)."
            exit 1
        fi
    fi

    resolve_brew_groups
    validate_selection || exit 1

    export flg_DryRun flg_Packages flg_Shell flg_Configs
    export flg_WmConfigs flg_WmServices flg_SbarConfigs flg_SbarService flg_Macos
    export DOTFILES_BREW_CLI="${brew_cli}"
    export DOTFILES_BREW_APPS="${brew_apps}"
    export DOTFILES_BREW_WM="${brew_wm}"
    export DOTFILES_BREW_SKETCHYBAR="${brew_sbar}"

    need_pre=0
    if [[ "${flg_Packages}" -eq 1 || "${flg_Configs}" -eq 1 || "${flg_WmConfigs}" -eq 1 || "${flg_SbarConfigs}" -eq 1 ]]; then
        need_pre=1
    fi

    if [[ "${flg_DryRun}" -eq 1 ]]; then
        describe_plan
        exit 0
    fi

    if [[ "$(uname)" != "Darwin" ]]; then
        print_log -err "Platform" "This installer is for macOS only"
        exit 1
    fi

    echo ""
    if ui_rich; then
        {
            echo "## roost — install plan"
            [[ "${flg_Packages}" -eq 1 ]] && echo "- **Packages** — cli=${brew_cli} apps=${brew_apps} wm=${brew_wm} sketchybar=${brew_sbar}"
            [[ "${flg_Shell}" -eq 1 ]] && echo "- **Shell environment**"
            [[ "${flg_Configs}" -eq 1 ]] && echo "- **Base dotfiles**"
            [[ "${flg_WmConfigs}" -eq 1 ]] && echo "- **Window-manager configs** (yabai / skhd / borders)"
            [[ "${flg_SbarConfigs}" -eq 1 ]] && echo "- **SketchyBar config**"
            [[ "${flg_WmServices}" -eq 1 ]] && echo "- **Window-manager services**"
            [[ "${flg_SbarService}" -eq 1 ]] && echo "- **SketchyBar service**"
            if [[ "${flg_Macos}" -eq 1 ]]; then
                if [[ -n "${hostName}" ]]; then
                    echo "- **macOS defaults** — hostname \`${hostName}\`"
                else
                    echo "- **macOS defaults**"
                fi
            fi
        } | gum format
    else
        print_log -info "Plan" "Selected:"
        [[ "${flg_Packages}" -eq 1 ]] && print_log -g " +" "Packages (cli=${brew_cli} apps=${brew_apps} wm=${brew_wm} sketchybar=${brew_sbar})"
        [[ "${flg_Shell}" -eq 1 ]] && print_log -g " +" "Shell environment"
        [[ "${flg_Configs}" -eq 1 ]] && print_log -g " +" "Base dotfiles"
        [[ "${flg_WmConfigs}" -eq 1 ]] && print_log -g " +" "Window-manager configs"
        [[ "${flg_SbarConfigs}" -eq 1 ]] && print_log -g " +" "SketchyBar config"
        [[ "${flg_WmServices}" -eq 1 ]] && print_log -g " +" "Window-manager services"
        [[ "${flg_SbarService}" -eq 1 ]] && print_log -g " +" "SketchyBar service"
        if [[ "${flg_Macos}" -eq 1 ]]; then
            if [[ -n "${hostName}" ]]; then
                print_log -g " +" "macOS defaults (hostname ${hostName})"
            else
                print_log -g " +" "macOS defaults"
            fi
        fi
    fi
    echo ""

    if [[ "${need_pre}" -eq 1 && "${pre_done:-0}" -ne 1 ]]; then
        print_log -info "Pre-Install" "Running prerequisites..."
        "${scrDir}/install_pre.sh"
        # Brew was just installed in a child — surface it here so the package
        # step (and other brew callers spawned from us) find it on PATH.
        ensure_brew_on_path
    fi

    if [[ "${flg_Packages}" -eq 1 ]]; then
        print_log -info "Packages" "Installing from Brewfile..."
        "${scrDir}/install_pkg.sh"
        if [[ "${brew_sbar}" -eq 1 ]]; then
            print_log -info "SketchyBar" "Setting up SketchyBar dependencies..."
            "${scrDir}/install_sketchybar.sh"
        fi
    fi

    # Offer Touch ID for sudo before the sudo-heavy steps (macOS defaults), so
    # those prompts can be approved by fingerprint. Runs only if mole is present.
    maybe_enable_touchid

    if [[ "${flg_Shell}" -eq 1 ]]; then
        print_log -info "Shell" "Setting up shell environment..."
        "${scrDir}/install_shell.sh"
    fi

    if [[ "${flg_Configs}" -eq 1 ]]; then
        print_log -info "Base dotfiles" "Linking base dotfiles..."
        setup_git_identity
        if resolve_link_conflicts "${repoDir}/install.conf.yaml"; then
            (
                cd "${repoDir}"
                ./install -c install.conf.yaml
            )
        fi
    fi

    if [[ "${flg_WmConfigs}" -eq 1 ]]; then
        print_log -info "WM configs" "Linking window-manager configs (yabai / skhd / borders)..."
        if resolve_link_conflicts "${repoDir}/install.wm.conf.yaml"; then
            (
                cd "${repoDir}"
                ./install -c install.wm.conf.yaml
            )
        fi
    fi

    if [[ "${flg_SbarConfigs}" -eq 1 ]]; then
        print_log -info "SketchyBar config" "Linking the SketchyBar config..."
        if resolve_link_conflicts "${repoDir}/install.sketchybar.conf.yaml"; then
            (
                cd "${repoDir}"
                ./install -c install.sketchybar.conf.yaml
            )
        fi
    fi

    if [[ "${flg_Macos}" -eq 1 ]]; then
        print_log -info "macOS" "Applying system defaults..."
        # Prefer the hostname picked interactively; fall back to a COMPUTER_NAME
        # from the environment (flag-driven runs). Empty → macos.sh leaves it.
        COMPUTER_NAME="${hostName:-${COMPUTER_NAME:-}}" bash "${scrDir}/macos.sh"
    fi

    if [[ "${flg_WmServices}" -eq 1 || "${flg_SbarService}" -eq 1 ]]; then
        print_log -info "Services" "Starting selected services..."
        DOTFILES_START_WM="${flg_WmServices}" DOTFILES_START_SBAR="${flg_SbarService}" \
            "${scrDir}/install_services.sh"
    fi

    print_log -g "SUCCESS" "Installation finished"
    if ui_rich; then
        {
            echo "# Next steps"
            echo "- Restart your terminal, or \`source ~/.zshrc\`"
            [[ "${flg_Shell}" -eq 1 ]] && echo "- Run \`p10k configure\` to customize your prompt"
            [[ "${flg_WmServices}" -eq 1 || "${brew_wm}" -eq 1 ]] && echo "- Log out/in so window management picks up Accessibility permissions"
            echo "- See \`README.md\` for customization and key bindings"
        } | gum format
    else
        print_log -info "Next" "Restart your terminal (or source ~/.zshrc)"
        [[ "${flg_Shell}" -eq 1 ]] && print_log -info "Next" "Run 'p10k configure' to customize your prompt"
        [[ "${flg_WmServices}" -eq 1 || "${brew_wm}" -eq 1 ]] && print_log -info "Next" "Log out/in so window management picks up Accessibility permissions"
        print_log -info "Docs" "See README.md for customization and key bindings"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
