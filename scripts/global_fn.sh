#!/usr/bin/env bash
# Shared helpers for the macOS dotfiles installer.

set -euo pipefail

scrDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoDir="$(cd "${scrDir}/.." && pwd)"
configDir="${repoDir}/configs"
homeDir="${HOME}"
cacheDir="${XDG_CACHE_HOME:-${HOME}/.cache}/dotfiles"

export scrDir repoDir configDir homeDir cacheDir

pkg_installed() {
    local pkgName=$1
    brew list --formula "${pkgName}" &>/dev/null || brew list --cask "${pkgName}" &>/dev/null
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

homebrew_installed() {
    command_exists brew
}

ensure_brew_on_path() {
    # Put a freshly-installed Homebrew on PATH for THIS process (and its
    # children, since brew shellenv exports PATH). Needed on a first run: the
    # installer added brew, but the shell that launched us never re-read its
    # profile, so `brew`/`gum` aren't found until this runs.
    command_exists brew && return 0
    local b
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "${b}" ]]; then
            eval "$("${b}" shellenv)"
            return 0
        fi
    done
    return 0
}

xcode_tools_installed() {
    xcode-select -p &>/dev/null
}

is_tty() {
    # Prefer a real controlling terminal so curl|bash still gets a picker.
    [[ -r /dev/tty && -w /dev/tty ]] || [[ -t 0 && -t 1 ]]
}

has_gum() {
    command -v gum >/dev/null 2>&1
}

ui_rich() {
    # Rich gum UI only when not in --yes mode, gum is present, and interactive.
    [[ "${use_default:-}" != "--yes" ]] && has_gum && is_tty
}

prompt_yes_no() {
    # prompt_yes_no "Question" default_yes|default_no
    local prompt=$1
    local default=${2:-default_yes}
    local reply
    local tty_in=/dev/tty

    if [[ "${use_default:-}" == "--yes" ]]; then
        [[ "${default}" == "default_yes" ]] && return 0 || return 1
    fi

    if ui_rich; then
        local gum_default=true
        [[ "${default}" == "default_no" ]] && gum_default=false
        if gum confirm --default="${gum_default}" "${prompt}"; then
            return 0
        else
            return 1
        fi
    fi

    if [[ ! -r "${tty_in}" ]]; then
        tty_in=/dev/stdin
    fi

    if [[ "${default}" == "default_yes" ]]; then
        read -r -p "${prompt} [Y/n] " reply <"${tty_in}" || true
        [[ -z "${reply}" || "${reply}" =~ ^[Yy]$ ]]
    else
        read -r -p "${prompt} [y/N] " reply <"${tty_in}" || true
        [[ "${reply}" =~ ^[Yy]$ ]]
    fi
}

prompt_input() {
    # prompt_input "Label" "default" -> echoes entered value (or default)
    local label=$1
    local default=${2:-}
    local reply

    if [[ "${use_default:-}" == "--yes" ]] || ! is_tty; then
        printf '%s' "${default}"
        return 0
    fi

    if ui_rich; then
        gum input --prompt "${label}: " --value "${default}" --placeholder "${default}"
        return 0
    fi

    read -r -p "${label} [${default}]: " reply </dev/tty || true
    printf '%s' "${reply:-${default}}"
}

print_section() {
    local title=$1
    if ui_rich; then
        gum style --border rounded --padding "0 1" --margin "1 0" \
            --border-foreground 212 "${title}"
    else
        print_log -b "==>" "${title}"
    fi
}

run_spin() {
    # run_spin "Title" cmd args...
    # Show a gum spinner for a long step (output preserved via --show-output);
    # otherwise run the command directly so its output streams normally.
    local title=$1
    shift
    if ui_rich; then
        gum spin --spinner dot --show-output --title "${title}" -- "$@"
    else
        "$@"
    fi
}

on_error() {
    # ERR-trap handler: report the failing command, line, and script.
    local exit_code=$?
    local line=${1:-?}
    local cmd=${2:-?}
    print_log -err "Failed" "Exit ${exit_code} at ${BASH_SOURCE[1]:-script}:${line} — ${cmd}"
    print_log -info "Logs" "Details in ${cacheDir}/logs"
    exit "${exit_code}"
}

enable_error_trap() {
    # Opt-in from a script's top level (or main) to get a clear failure report
    # instead of a silent abort. errtrace makes the trap fire inside functions.
    set -o errtrace
    trap 'on_error "${LINENO}" "${BASH_COMMAND}"' ERR
}

with_retry() {
    # with_retry <max> cmd args...  — retry a (network) command with linear backoff.
    local max=$1
    shift
    local attempt=1
    until "$@"; do
        if ((attempt >= max)); then
            print_log -err "Retry" "Failed after ${max} attempts: $*"
            return 1
        fi
        print_log -y "Retry" "Attempt ${attempt}/${max} failed; retrying in $((attempt * 3))s..."
        sleep "$((attempt * 3))"
        ((attempt++)) || true
    done
}

_log_to_file() {
    # Append a plain (ANSI-free) line to the session log, best-effort.
    local line=$1
    local logDir="${cacheDir}/logs"
    mkdir -p "${logDir}" 2>/dev/null || return 0
    printf '%s\n' "${line}" >>"${logDir}/$(date +'%y%m%d_%Hh%Mm%Ss').log"
}

print_log() {
    # print_log [-sec SECTION] -TAG "Label" "Message"
    # TAG: -info | -warn | -y (notice) | -err | -r (error) | -crit | -g (success) | -b (step)
    # Renders via `gum log` when gum is present, else a compact ANSI line.
    local sec=""
    if [[ "${1:-}" == "-sec" ]]; then
        sec="$2"
        shift 2
    fi
    local tag="${1:-}"
    local label="${2:-}"
    local message="${3:-}"

    local level="info"
    case "${tag}" in
        -warn | -y) level="warn" ;;
        -err | -r | -crit) level="error" ;;
        *) level="info" ;;
    esac

    local sec_prefix=""
    [[ -n "${sec}" ]] && sec_prefix="[${sec}] "
    _log_to_file "${sec_prefix}${label}: ${message}"

    if has_gum; then
        if [[ -n "${sec}" ]]; then
            gum log --level "${level}" --prefix "${sec}" "${label}: ${message}" >&2
        else
            gum log --level "${level}" "${label}: ${message}" >&2
        fi
        return 0
    fi

    local reset=$'\033[0m' color=""
    case "${tag}" in
        -err | -r | -crit) color=$'\033[31m' ;;
        -warn | -y) color=$'\033[33m' ;;
        -g) color=$'\033[32m' ;;
        -b) color=$'\033[34m' ;;
        *) color=$'\033[36m' ;;
    esac
    printf '%s%s%s %s\n' "${color}" "${sec_prefix}${label}" "${reset}" "${message}" >&2
}

check_macos_version() {
    local version major
    version="$(sw_vers -productVersion)"
    major="$(printf '%s' "${version}" | cut -d. -f1)"

    print_log -info "macOS Version" "Detected macOS ${version}"

    if [[ "${major}" -lt 12 ]]; then
        print_log -err "Compatibility" "Requires macOS 12.0 or later"
        return 1
    fi
    return 0
}

backup_existing() {
    local target=$1
    local backup_dir
    backup_dir="${repoDir}/backups/$(date +'%Y%m%d_%H%M%S')"

    if [[ -e "${target}" ]]; then
        print_log -warn "Backup" "Creating backup of ${target}"
        mkdir -p "${backup_dir}"
        cp -R "${target}" "${backup_dir}/"
        print_log -g "Success" "Backup created at ${backup_dir}"
    fi
}

install_oh_my_zsh() {
    if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
        print_log -info "Oh My Zsh" "Installing Oh My Zsh..."
        # Keep the curl inside the retried command so a transient download
        # failure is actually re-fetched (not just the already-downloaded script).
        # SC2016: the $(curl) is intentionally left unexpanded so bash -c runs it each retry.
        # shellcheck disable=SC2016
        with_retry 3 run_spin "Installing Oh My Zsh" \
            bash -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
        print_log -g "Success" "Oh My Zsh installed"
    else
        print_log -y "Skip" "Oh My Zsh already installed"
    fi
}

install_powerlevel10k() {
    local p10k_dir="${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"

    if [[ ! -d "${p10k_dir}" ]]; then
        print_log -info "Powerlevel10k" "Installing Powerlevel10k..."
        with_retry 3 run_spin "Cloning Powerlevel10k" \
            git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${p10k_dir}"
        print_log -g "Success" "Powerlevel10k installed"
    else
        print_log -y "Skip" "Powerlevel10k already installed"
    fi
}

install_nvm() {
    if [[ ! -d "${HOME}/.nvm" ]]; then
        print_log -info "nvm" "Installing nvm (Node Version Manager)..."
        with_retry 3 run_spin "Cloning nvm" \
            git clone https://github.com/nvm-sh/nvm.git "${HOME}/.nvm"
        (
            cd "${HOME}/.nvm"
            git checkout "$(git describe --abbrev=0 --tags --match 'v[0-9]*' "$(git rev-list --tags --max-count=1)")"
        )
        print_log -g "Success" "NVM installed"
    else
        print_log -y "Skip" "NVM already installed"
    fi
}

run_brewfile() {
    local brewfile=$1
    if [[ ! -f "${brewfile}" ]]; then
        print_log -err "Missing" "Brewfile not found: ${brewfile}"
        return 1
    fi
    print_log -info "Brewfile" "Installing from ${brewfile}"
    # Homebrew strips environment variables that lack a HOMEBREW_ prefix before
    # evaluating the Brewfile, so forward the DOTFILES_BREW_* group flags under
    # that prefix. The subshell keeps the forwarded names out of the caller.
    (
        local group flag
        for group in CLI APPS WM SKETCHYBAR; do
            flag="DOTFILES_BREW_${group}"
            export "HOMEBREW_DOTFILES_BREW_${group}=${!flag:-1}"
        done
        brew bundle install --file="${brewfile}"
    )
}
