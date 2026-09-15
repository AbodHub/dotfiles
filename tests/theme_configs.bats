setup() {
    cd "${BATS_TEST_DIRNAME}/.."
    CONF="configs/theme/tinty/config.toml"
    TEMPLATES="configs/theme/tinty/templates"
}

@test "every tinty item declares supported-systems explicitly" {
    items="$(grep -c '^name = ' "${CONF}")"
    systems="$(grep -c '^supported-systems = ' "${CONF}")"
    [ "${items}" -gt 0 ]
    [ "${items}" -eq "${systems}" ]
}

@test "no tinty item opts into base24 (upstream templates are base16-only)" {
    ! grep -q 'base24' "${CONF}"
}

@test "every local template path in config.toml exists with a builder config" {
    while IFS= read -r name; do
        [ -f "${TEMPLATES}/${name}/templates/config.yaml" ]
        [ -f "${TEMPLATES}/${name}/templates/default.mustache" ]
    done < <(sed -n 's|^path = "~/.config/tinted-theming/tinty/templates/\([^"]*\)"|\1|p' "${CONF}")
}

@test "no tinty hook contains a single quote (tinty runs hooks inside bash -c '...')" {
    python3 -c 'import tomllib' 2>/dev/null || skip "python3 with tomllib not available"
    run python3 -c '
import sys, tomllib
items = tomllib.load(open(sys.argv[1], "rb"))["items"]
bad = [i["name"] for i in items if chr(39) in i.get("hook", "")]
print(" ".join(bad)); sys.exit(1 if bad else 0)' "${CONF}"
    [ "$status" -eq 0 ]
}

hook_of() {
    python3 -c 'import sys, tomllib; print(next(i["hook"] for i in tomllib.load(open(sys.argv[1], "rb"))["items"] if i["name"] == sys.argv[2]))' "${CONF}" "$1"
}

@test "warp hook runs the Warp hook script with the rendered file" {
    python3 -c 'import tomllib' 2>/dev/null || skip "python3 with tomllib not available"
    [ "$(hook_of warp)" = '"$HOME/.config/tinted-theming/tinty/hooks/warp.sh" "$TINTY_THEME_FILE_PATH"' ]
    [ -x configs/theme/tinty/hooks/warp.sh ]
}

warp_setup() {
    home="${BATS_TEST_TMPDIR}/home"
    src="${BATS_TEST_TMPDIR}/base16-demo.yaml"
    mkdir -p "${home}"
    printf 'name: Base16 Demo\nbackground: "#101010"\n' >"${src}"
}

warp_settings() {
    mkdir -p "${home}/.warp"
    printf '[appearance.themes]\nsystem_theme = %s\nselected_system_themes = {\n  dark = { custom = { name = "%s", path = "%s" } },\n}\n' \
        "$1" "$2" "$3" >"${home}/.warp/settings.toml"
}

@test "Warp hook does nothing before Warp has run" {
    warp_setup
    run env HOME="${home}" configs/theme/tinty/hooks/warp.sh "${src}"
    [ "$status" -eq 0 ]
    [ ! -e "${home}/.warp" ]
}

@test "Warp hook installs tinty.yaml with the name pinned to tinty" {
    warp_setup
    warp_settings false tinty tinty.yaml
    run env HOME="${home}" WARP_TOGGLE_DELAY=0 configs/theme/tinty/hooks/warp.sh "${src}"
    [ "$status" -eq 0 ]
    grep -qx 'name: tinty' "${home}/.warp/themes/tinty.yaml"
    grep -q '#101010' "${home}/.warp/themes/tinty.yaml"
    ! ls -a "${home}/.warp/themes" | grep -q '^\.tinty\.'
}

@test "Warp hook leaves settings alone unless Sync with OS is on with tinty selected" {
    warp_setup
    for case in "false tinty tinty.yaml" "true Dracula dracula.yaml"; do
        # shellcheck disable=SC2086
        warp_settings ${case}
        cp "${home}/.warp/settings.toml" "${BATS_TEST_TMPDIR}/before.toml"
        run env HOME="${home}" WARP_TOGGLE_DELAY=0 configs/theme/tinty/hooks/warp.sh "${src}"
        [ "$status" -eq 0 ]
        cmp "${BATS_TEST_TMPDIR}/before.toml" "${home}/.warp/settings.toml"
    done
}

@test "Warp hook toggles Sync with OS off, then back on" {
    warp_setup
    warp_settings true tinty tinty.yaml
    env HOME="${home}" WARP_TOGGLE_DELAY=1 configs/theme/tinty/hooks/warp.sh "${src}" &
    pid=$!
    sleep 0.4
    grep -qx 'system_theme = false' "${home}/.warp/settings.toml"
    wait "${pid}"
    grep -qx 'system_theme = true' "${home}/.warp/settings.toml"
}

@test "Warp hook turns Sync with OS back on when interrupted" {
    warp_setup
    warp_settings true tinty tinty.yaml
    env HOME="${home}" WARP_TOGGLE_DELAY=2 configs/theme/tinty/hooks/warp.sh "${src}" &
    pid=$!
    sleep 0.4
    kill -TERM "${pid}"
    wait "${pid}" || true
    grep -qx 'system_theme = true' "${home}/.warp/settings.toml"
}

@test "Claude Code hook does nothing before Claude Code has run, then installs tinty.json" {
    python3 -c 'import tomllib' 2>/dev/null || skip "python3 with tomllib not available"
    home="${BATS_TEST_TMPDIR}/home"
    mkdir -p "${home}"
    src="${BATS_TEST_TMPDIR}/base16-demo.json"
    printf '{"name": "Demo", "base": "dark"}\n' >"${src}"
    hook="$(hook_of claude-code)"

    run env HOME="${home}" TINTY_THEME_FILE_PATH="${src}" bash -c "${hook}"
    [ "$status" -eq 0 ]
    [ ! -e "${home}/.claude" ]

    mkdir -p "${home}/.claude"
    run env HOME="${home}" TINTY_THEME_FILE_PATH="${src}" bash -c "${hook}"
    [ "$status" -eq 0 ]
    cmp "${src}" "${home}/.claude/themes/tinty.json"
}

@test "tinty items are named after the app they theme" {
    run sed -n 's/^name = "\(.*\)"$/\1/p' "${CONF}"
    [ "${output}" = "$(printf '%s\n' fzf tmux delta lazygit yazi vivid warp claude-code sketchybar borders yabai btop p10k)" ]
}

@test "pins.tsv only pins known apps to dark, light, or a scheme id" {
    [ -f configs/theme/tinty/pins.tsv ]
    while IFS=$'\t' read -r app pin; do
        case "${app}" in "" | \#*) continue ;; esac
        grep -qx "name = \"${app}\"" "${CONF}"
        [[ "${pin}" =~ ^(dark|light|base16-.+)$ ]]
    done <configs/theme/tinty/pins.tsv
}

@test "groups.tsv only groups known apps, and no group shadows an app" {
    grep -qx "$(printf 'terminal\twarp,claude-code,lazygit,yazi,vivid,p10k,delta,fzf,tmux,btop')" configs/theme/tinty/groups.tsv
    while IFS=$'\t' read -r group apps; do
        case "${group}" in "" | \#*) continue ;; esac
        ! grep -qx "name = \"${group}\"" "${CONF}"
        for app in ${apps//,/ }; do
            grep -qx "name = \"${app}\"" "${CONF}"
        done
    done <configs/theme/tinty/groups.tsv
}

@test "roost templates render into build/ and stay base16" {
    for cfg in "${TEMPLATES}"/*/templates/config.yaml; do
        grep -q 'filename: build/{{ scheme-system }}-{{ scheme-slug }}\.' "${cfg}"
        grep -q 'supported-systems: \[base16\]' "${cfg}"
    done
}

@test "every roost template uses palette variables" {
    for tpl in "${TEMPLATES}"/*/templates/default.mustache; do
        grep -q '{{base0[0-9A-F]-hex}}' "${tpl}"
    done
}

@test "families.tsv rows have four tab-separated columns and base16 ids" {
    awk -F'\t' '!/^#/ && NF { if (NF != 4) exit 1; if ($2 !~ /^base16-/ || $3 !~ /^base16-/) exit 1 }' \
        configs/theme/tinty/families.tsv
}

@test "families.tsv lists the agreed families" {
    for fam in ayu catppuccin github gruvbox nord one rose-pine tokyonight; do
        grep -q "^${fam}"$'\t' configs/theme/tinty/families.tsv
    done
}
