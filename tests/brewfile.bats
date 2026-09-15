setup() {
    cd "${BATS_TEST_DIRNAME}/.."
    source scripts/brewfile.sh
    FIXTURE="${BATS_TEST_TMPDIR}/Brewfile"
    cat >"${FIXTURE}" <<'EOF'
cli = ENV.fetch("DOTFILES_BREW_CLI", "1") == "1"
tap "felixkratz/formulae" if sbar || wm
brew "gum" if cli
cask "raycast" if apps
mas "Xcode", id: 497799835 if apps
brew "yabai" if wm
brew "borders" if wm
brew "sketchybar" if sbar
EOF

    # Evaluate a Brewfile with a stub DSL and print every package it would install.
    BREWFILE_EVAL='
        $pkgs = []
        def tap(*_args, **_opts); end
        def brew(name, **_opts); $pkgs << "brew:#{name}"; end
        def cask(name, **_opts); $pkgs << "cask:#{name}"; end
        def mas(name, **_opts); $pkgs << "mas:#{name}"; end
        eval(File.read(ARGV[0]), binding, ARGV[0])
        puts $pkgs'
}

@test "candidates for wm list yabai and borders" {
    run brewfile_candidates "${FIXTURE}" wm
    [[ "${output}" == *"yabai"* ]]
    [[ "${output}" == *"borders"* ]]
}

@test "candidates exclude other groups" {
    run brewfile_candidates "${FIXTURE}" wm
    [[ "${output}" != *"raycast"* ]]
    [[ "${output}" != *"gum"* ]]
}

@test "mas spec is preserved verbatim" {
    run brewfile_candidates "${FIXTURE}" apps
    [[ "${output}" == *'"Xcode", id: 497799835'* ]]
}

@test "generate keeps selected packages plus active taps, drops the rest" {
    keep="${BATS_TEST_TMPDIR}/keep"
    printf 'brew:yabai\n' >"${keep}"
    run brewfile_generate "${FIXTURE}" 0 0 1 0 "${keep}"
    [[ "${output}" == *'brew "yabai"'* ]]
    [[ "${output}" == *'tap "felixkratz/formulae"'* ]]
    [[ "${output}" != *"borders"* ]]
}

@test "generate excludes packages from disabled groups" {
    keep="${BATS_TEST_TMPDIR}/keep"
    printf 'cask:raycast\n' >"${keep}"
    run brewfile_generate "${FIXTURE}" 1 0 0 0 "${keep}"
    [[ "${output}" != *"raycast"* ]]
}

@test "generated filtered Brewfile has no ruby conditionals" {
    keep="${BATS_TEST_TMPDIR}/keep"
    printf 'brew:gum\n' >"${keep}"
    run brewfile_generate "${FIXTURE}" 1 0 0 0 "${keep}"
    [[ "${output}" != *" if "* ]]
    [[ "${output}" != *"ENV.fetch"* ]]
}

@test "Brewfile gates groups on HOMEBREW_DOTFILES_BREW_* (the names Homebrew passes through)" {
    command -v ruby >/dev/null 2>&1 || skip "ruby not installed"
    run env HOMEBREW_DOTFILES_BREW_CLI=0 HOMEBREW_DOTFILES_BREW_APPS=0 \
        HOMEBREW_DOTFILES_BREW_WM=1 HOMEBREW_DOTFILES_BREW_SKETCHYBAR=0 \
        ruby -e "${BREWFILE_EVAL}" Brewfile
    [ "$status" -eq 0 ]
    [[ "${output}" == *"brew:yabai"* ]]
    [[ "${output}" != *"brew:gum"* ]]
    [[ "${output}" != *"cask:raycast"* ]]
    [[ "${output}" != *"brew:sketchybar"* ]]
}

@test "Brewfile installs every group when no group flag is set" {
    command -v ruby >/dev/null 2>&1 || skip "ruby not installed"
    run ruby -e "${BREWFILE_EVAL}" Brewfile
    [ "$status" -eq 0 ]
    [[ "${output}" == *"brew:gum"* ]]
    [[ "${output}" == *"cask:raycast"* ]]
    [[ "${output}" == *"brew:yabai"* ]]
    [[ "${output}" == *"brew:sketchybar"* ]]
}

@test "run_brewfile forwards group flags to Homebrew under the HOMEBREW_ prefix" {
    source scripts/global_fn.sh
    envlog="${BATS_TEST_TMPDIR}/env"
    print_log() { :; }
    brew() { env | grep '^HOMEBREW_DOTFILES_BREW_' | sort >"${envlog}"; }
    export DOTFILES_BREW_CLI=0 DOTFILES_BREW_APPS=1 DOTFILES_BREW_WM=0
    unset DOTFILES_BREW_SKETCHYBAR
    run_brewfile "${FIXTURE}"
    grep -qx 'HOMEBREW_DOTFILES_BREW_CLI=0' "${envlog}"
    grep -qx 'HOMEBREW_DOTFILES_BREW_APPS=1' "${envlog}"
    grep -qx 'HOMEBREW_DOTFILES_BREW_WM=0' "${envlog}"
    grep -qx 'HOMEBREW_DOTFILES_BREW_SKETCHYBAR=1' "${envlog}"
    # forwarded in a subshell only; the caller's environment stays untouched
    [ -z "${HOMEBREW_DOTFILES_BREW_CLI:-}" ]
}
