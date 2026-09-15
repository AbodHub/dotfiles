setup() {
    cd "${BATS_TEST_DIRNAME}/.."
    export THEME_FAMILIES="${BATS_TEST_TMPDIR}/families.tsv"
    export THEME_STATE_DIR="${BATS_TEST_TMPDIR}/state"
    export THEME_TEMPLATES="${BATS_TEST_TMPDIR}/templates"
    export THEME_PINS="${BATS_TEST_TMPDIR}/pins.tsv"
    export THEME_GROUPS="${BATS_TEST_TMPDIR}/groups.tsv"
    printf '# group\tapps\nterm\twarp,fzf\n' >"${THEME_GROUPS}"
    export THEME_TINTY_CONFIG="${BATS_TEST_TMPDIR}/config.toml"
    export THEME_DATA="${BATS_TEST_TMPDIR}/data"
    export HOOK_LOG="${BATS_TEST_TMPDIR}/hook.log"
    TINTY_LOG="${BATS_TEST_TMPDIR}/tinty.log"
    CURRENT="${BATS_TEST_TMPDIR}/current"
    : >"${TINTY_LOG}"
    : >"${HOOK_LOG}"
    printf '# app\tpin\n' >"${THEME_PINS}"

    # Two apps: warp has a hook (with escaped quotes, as in the real config), fzf has none.
    cat >"${THEME_TINTY_CONFIG}" <<'TOML'
shell = "bash -c '{}'"

[[items]]
name = "warp"
path = "https://example.invalid/tinted-terminal"
themes-dir = "themes/warp"
hook = "cat >/dev/null; echo \"$TINTY_SCHEME_ID $TINTY_THEME_FILE_PATH\" >> \"$HOOK_LOG\""
supported-systems = ["base16"]

[[items]]
name = "fzf"
path = "https://example.invalid/tinted-fzf"
themes-dir = "sh"
supported-systems = ["base16"]
TOML
    local scheme
    mkdir -p "${THEME_DATA}/repos/warp/themes/warp" "${THEME_DATA}/repos/fzf/sh"
    for scheme in base16-catppuccin-mocha base16-catppuccin-latte base16-gruvbox-dark-medium base16-gruvbox-light-medium base16-nord; do
        printf '%s\n' "${scheme}" >"${THEME_DATA}/repos/warp/themes/warp/${scheme}.yaml"
        printf '%s\n' "${scheme}" >"${THEME_DATA}/repos/fzf/sh/${scheme}.sh"
    done
    printf '# family\tdark\tlight\tvariants\n' >"${THEME_FAMILIES}"
    printf 'catppuccin\tbase16-catppuccin-mocha\tbase16-catppuccin-latte\tbase16-catppuccin-frappe,base16-catppuccin-macchiato\n' >>"${THEME_FAMILIES}"
    printf 'gruvbox\tbase16-gruvbox-dark-medium\tbase16-gruvbox-light-medium\t\n' >>"${THEME_FAMILIES}"

    source configs/theme/bin/theme

    # Stub the engine and the appearance probe.
    tinty() {
        printf '%s\n' "$*" >>"${TINTY_LOG}"
        case "$1" in
            apply) printf '%s' "$2" >"${CURRENT}" ;;
            list) printf 'base16-catppuccin-mocha\nbase16-catppuccin-latte\nbase16-catppuccin-frappe\nbase16-catppuccin-macchiato\nbase16-gruvbox-dark-medium\nbase16-gruvbox-light-medium\nbase16-nord\n' ;;
            current) [[ -f "${CURRENT}" ]] && cat "${CURRENT}" ;;
        esac
    }
    APPEARANCE=dark
    appearance() { printf '%s\n' "${APPEARANCE}"; }
}

applied() { grep -qx "apply $1" "${TINTY_LOG}"; }

@test "set <family> applies the dark variant when macOS is dark" {
    APPEARANCE=dark
    main set gruvbox
    applied base16-gruvbox-dark-medium
    [ "$(cat "${THEME_STATE_DIR}/family")" = "gruvbox" ]
}

@test "set <family> applies the light variant when macOS is light" {
    APPEARANCE=light
    main set catppuccin
    applied base16-catppuccin-latte
}

@test "sync <mode> overrides detection" {
    main set gruvbox
    : >"${TINTY_LOG}"
    main sync light
    applied base16-gruvbox-light-medium
}

@test "dark and light force the variant regardless of appearance" {
    APPEARANCE=light
    main set gruvbox
    : >"${TINTY_LOG}"
    main dark
    applied base16-gruvbox-dark-medium
    : >"${TINTY_LOG}"
    main light
    applied base16-gruvbox-light-medium
}

@test "set <scheme-id> applies it exactly and remembers the owning family" {
    main set base16-catppuccin-frappe
    applied base16-catppuccin-frappe
    [ "$(cat "${THEME_STATE_DIR}/family")" = "catppuccin" ]
}

@test "set <scheme-id> outside every family applies it and leaves the family unset" {
    main set base16-nord
    applied base16-nord
    [ ! -e "${THEME_STATE_DIR}/family" ]
}

@test "set with an unknown name fails without applying" {
    run main set nope
    [ "$status" -ne 0 ]
    ! grep -q '^apply' "${TINTY_LOG}"
}

@test "sync without a chosen family fails" {
    run main sync
    [ "$status" -ne 0 ]
}

@test "sync rejects a mode other than dark or light" {
    main set gruvbox
    run main sync sideways
    [ "$status" -ne 0 ]
}

@test "list shows every family and marks the current one" {
    main set gruvbox
    run main list
    [ "$status" -eq 0 ]
    [[ "${output}" == *"* gruvbox"* ]]
    [[ "${output}" == *"  catppuccin"* ]]
}

@test "rebuild builds each local template dir that has a builder config" {
    mkdir -p "${THEME_TEMPLATES}/alpha/templates" "${THEME_TEMPLATES}/skipme"
    : >"${THEME_TEMPLATES}/alpha/templates/config.yaml"
    main rebuild
    grep -q "build ${THEME_TEMPLATES}/alpha" "${TINTY_LOG}"
    ! grep -q "skipme" "${TINTY_LOG}"
}

@test "unknown subcommand fails" {
    run main frobnicate
    [ "$status" -ne 0 ]
}

warp_artifact() { cat "${THEME_DATA}/artifacts/warp-themes-warp-file.yaml"; }

@test "pin saves the pin and renders the app with it right away" {
    APPEARANCE=light
    main set gruvbox
    main pin warp dark
    [ "$(grep -v '^#' "${THEME_PINS}")" = "$(printf 'warp\tdark')" ]
    [ "$(warp_artifact)" = "base16-gruvbox-dark-medium" ]
    grep -qx "base16-gruvbox-dark-medium ${THEME_DATA}/artifacts/warp-themes-warp-file.yaml" "${HOOK_LOG}"
}

@test "sync re-renders pinned apps after applying the family" {
    printf 'warp\tdark\n' >>"${THEME_PINS}"
    APPEARANCE=light
    main set gruvbox
    applied base16-gruvbox-light-medium
    [ "$(warp_artifact)" = "base16-gruvbox-dark-medium" ]
}

@test "a pin that matches the applied scheme renders nothing extra" {
    printf 'warp\tdark\n' >>"${THEME_PINS}"
    APPEARANCE=dark
    main set gruvbox
    [ ! -s "${HOOK_LOG}" ]
    [ ! -e "${THEME_DATA}/artifacts/warp-themes-warp-file.yaml" ]
}

@test "a scheme pin renders that scheme, and apps without a hook still get their file" {
    APPEARANCE=dark
    main set gruvbox
    main pin fzf base16-catppuccin-latte
    [ "$(cat "${THEME_DATA}/artifacts/fzf-sh-file.sh")" = "base16-catppuccin-latte" ]
}

@test "every pin is applied even when a hook reads stdin" {
    printf 'warp\tlight\nfzf\tbase16-nord\n' >>"${THEME_PINS}"
    APPEARANCE=dark
    main set gruvbox
    [ "$(warp_artifact)" = "base16-gruvbox-light-medium" ]
    [ "$(cat "${THEME_DATA}/artifacts/fzf-sh-file.sh")" = "base16-nord" ]
}

@test "a mode pin is skipped when no family is selected" {
    printf 'warp\tdark\n' >>"${THEME_PINS}"
    run main set base16-nord
    [ "$status" -eq 0 ]
    [[ "${output}" == *"skipping pin warp=dark: no family selected"* ]]
    [ ! -s "${HOOK_LOG}" ]
}

@test "pin rejects unknown apps and schemes without changing pins" {
    cp "${THEME_PINS}" "${BATS_TEST_TMPDIR}/before"
    run main pin nope dark
    [ "$status" -ne 0 ]
    [[ "${output}" == *"unknown app or group: nope"* ]]
    run main pin warp base16-bogus
    [ "$status" -ne 0 ]
    cmp "${BATS_TEST_TMPDIR}/before" "${THEME_PINS}"
}

@test "pinning an app again replaces its pin" {
    main pin warp dark
    main pin warp light
    [ "$(grep -c '^warp' "${THEME_PINS}")" -eq 1 ]
    grep -qx "$(printf 'warp\tlight')" "${THEME_PINS}"
}

@test "unpin removes the pin and renders the app with the applied scheme" {
    APPEARANCE=light
    main set gruvbox
    main pin warp dark
    main unpin warp
    ! grep -q '^warp' "${THEME_PINS}"
    [ "$(warp_artifact)" = "base16-gruvbox-light-medium" ]
    run main unpin warp
    [ "$status" -ne 0 ]
}

@test "list shows pins" {
    main pin warp dark
    run main list
    [[ "${output}" == *"pinned"* ]]
    [[ "${output}" == *"warp"*"dark"* ]]
}

@test "pinning a group pins and renders every app in it" {
    APPEARANCE=light
    main set gruvbox
    main pin term dark
    grep -qx "$(printf 'warp\tdark')" "${THEME_PINS}"
    grep -qx "$(printf 'fzf\tdark')" "${THEME_PINS}"
    [ "$(warp_artifact)" = "base16-gruvbox-dark-medium" ]
    [ "$(cat "${THEME_DATA}/artifacts/fzf-sh-file.sh")" = "base16-gruvbox-dark-medium" ]
}

@test "unpinning a group unpins its pinned apps and leaves other pins alone" {
    APPEARANCE=light
    main set gruvbox
    main pin warp dark
    printf 'other\tlight\n' >>"${THEME_PINS}"
    main unpin term
    ! grep -q '^warp' "${THEME_PINS}"
    grep -q '^other' "${THEME_PINS}"
    [ "$(warp_artifact)" = "base16-gruvbox-light-medium" ]
    run main unpin term
    [ "$status" -ne 0 ]
}
