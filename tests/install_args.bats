setup() {
    cd "${BATS_TEST_DIRNAME}/.."
    source scripts/install.sh
}

@test "--all enables every component and brew group" {
    reset_flags
    parse_args --all
    [ "$flg_Packages" -eq 1 ]
    [ "$flg_Shell" -eq 1 ]
    [ "$flg_Configs" -eq 1 ]
    [ "$flg_WmConfigs" -eq 1 ]
    [ "$flg_WmServices" -eq 1 ]
    [ "$flg_SbarConfigs" -eq 1 ]
    [ "$flg_SbarService" -eq 1 ]
    [ "$flg_Macos" -eq 1 ]
    [ "$flg_Theme" -eq 1 ]
    [ "$brew_cli" -eq 1 ]
    [ "$brew_apps" -eq 1 ]
    [ "$brew_wm" -eq 1 ]
    [ "$brew_sbar" -eq 1 ]
    [ "$brew_theme" -eq 1 ]
}

@test "--services enables both WM and SketchyBar services" {
    reset_flags
    parse_args --services
    [ "$flg_WmServices" -eq 1 ]
    [ "$flg_SbarService" -eq 1 ]
}

@test "--sketchybar-configs is independent of --wm-configs" {
    reset_flags
    parse_args --sketchybar-configs
    [ "$flg_SbarConfigs" -eq 1 ]
    [ "$flg_WmConfigs" -eq 0 ]
}

@test "--no-brew-apps turns the apps group off" {
    reset_flags
    parse_args --packages --no-brew-apps
    [ "$flg_Packages" -eq 1 ]
    [ "$brew_apps" -eq 0 ]
}

@test "--reset-yabai sets the reset flag without components" {
    reset_flags
    parse_args --reset-yabai
    [ "$flg_ResetYabai" -eq 1 ]
    [ "$flg_AnyComponent" -eq 0 ]
}

@test "unknown flag exits non-zero" {
    run bash -c 'cd "'"${BATS_TEST_DIRNAME}"'/.." && source scripts/install.sh && reset_flags && parse_args --nope'
    [ "$status" -ne 0 ]
}

@test "packages selected, groups unset resolves all groups on" {
    reset_flags
    flg_Packages=1
    resolve_brew_groups
    [ "$brew_cli" -eq 1 ]
    [ "$brew_apps" -eq 1 ]
    [ "$brew_wm" -eq 1 ]
    [ "$brew_sbar" -eq 1 ]
    [ "$brew_theme" -eq 1 ]
}

@test "an explicit brew group implies packages and enables only that group" {
    reset_flags
    parse_args --brew-wm
    [ "$flg_AnyComponent" -eq 1 ]
    resolve_brew_groups
    [ "$flg_Packages" -eq 1 ]
    [ "$brew_wm" -eq 1 ]
    [ "$brew_cli" -eq 0 ]
    [ "$brew_apps" -eq 0 ]
    [ "$brew_sbar" -eq 0 ]
    [ "$brew_theme" -eq 0 ]
}

@test "packages not selected forces all groups off" {
    reset_flags
    resolve_brew_groups
    [ "$brew_cli" -eq 0 ]
    [ "$brew_apps" -eq 0 ]
    [ "$brew_wm" -eq 0 ]
    [ "$brew_sbar" -eq 0 ]
    [ "$brew_theme" -eq 0 ]
}

@test "packages on with all groups off fails validation" {
    reset_flags
    flg_Packages=1
    brew_cli=0 brew_apps=0 brew_wm=0 brew_sbar=0 brew_theme=0
    run validate_selection
    [ "$status" -ne 0 ]
}

@test "gum_picker maps feature selections and gated follow-ups to flags" {
    reset_flags
    # Stub the feature multi-select; skip per-package pruning and answer the
    # WM follow-ups "yes".
    gum() {
        case "$*" in
            *"What should roost set up"*) printf 'CLI tools & fonts\nWindow management (yabai + skhd + borders)\n' ;;
            *) printf '' ;;
        esac
    }
    select_packages() {
        wm_core_kept=1
        sbar_core_kept=1
        theme_core_kept=1
    }
    prompt_yes_no() { return 0; }

    gum_picker

    [ "$flg_Packages" -eq 1 ]
    [ "$brew_cli" -eq 1 ]
    [ "$brew_wm" -eq 1 ]
    [ "$brew_apps" -eq 0 ]
    [ "$brew_sbar" -eq 0 ]
    [ "$flg_Shell" -eq 0 ]
    # WM chosen, core kept, follow-ups answered yes
    [ "$flg_WmConfigs" -eq 1 ]
    [ "$flg_WmServices" -eq 1 ]
    [ "$flg_SbarConfigs" -eq 0 ]
}

@test "gum_picker skips WM follow-ups when yabai is pruned away" {
    reset_flags
    gum() {
        case "$*" in
            *"What should roost set up"*) printf 'Window management (yabai + skhd + borders)\n' ;;
            *) printf '' ;;
        esac
    }
    # Simulate the core package being dropped during pruning.
    select_packages() {
        wm_core_kept=0
        sbar_core_kept=1
        theme_core_kept=1
    }
    prompt_yes_no() { return 0; }

    gum_picker

    [ "$brew_wm" -eq 1 ]
    [ "$flg_WmConfigs" -eq 0 ]
    [ "$flg_WmServices" -eq 0 ]
}

@test "no components + non-interactive exits non-zero (no prompts)" {
    run bash -c '
        cd "'"${BATS_TEST_DIRNAME}"'/.."
        source scripts/install.sh
        is_tty() { return 1; }
        main
    '
    [ "$status" -ne 0 ]
}

@test "setup_git_identity appends the [user] block and keeps the rest of gitconfig" {
    configDir="${BATS_TEST_TMPDIR}/configs"
    mkdir -p "${configDir}/git"
    printf '[init]\n\tdefaultBranch = main\n[delta]\n\tnavigate = true\n' >"${configDir}/git/gitconfig"
    is_tty() { return 0; }
    prompt_input() {
        case "$1" in
            *name*) printf 'Test User' ;;
            *email*) printf 'test@example.com' ;;
        esac
    }
    prompt_yes_no() { return 1; }
    unset use_default
    setup_git_identity
    grep -q 'name = Test User' "${configDir}/git/gitconfig"
    grep -q 'navigate = true' "${configDir}/git/gitconfig"
    [ "$(grep -c 'defaultBranch' "${configDir}/git/gitconfig")" -eq 1 ]
}

@test "--theme enables the theme step and implies the theme brew group" {
    reset_flags
    parse_args --theme
    [ "$flg_Theme" -eq 1 ]
    [ "$brew_theme" -eq 1 ]
    [ "$flg_AnyComponent" -eq 1 ]
    resolve_brew_groups
    [ "$flg_Packages" -eq 1 ]
    [ "$brew_cli" -eq 0 ]
    [ "$brew_wm" -eq 0 ]
}

@test "--no-brew-theme turns the theme group off" {
    reset_flags
    parse_args --packages --no-brew-theme
    resolve_brew_groups
    [ "$brew_theme" -eq 0 ]
    [ "$brew_cli" -eq 1 ]
}

@test "gum_picker maps Theming to the theme flag and group" {
    reset_flags
    gum() {
        case "$*" in
            *"What should roost set up"*) printf 'Theming (tinty + auto light/dark)\n' ;;
            *) printf '' ;;
        esac
    }
    select_packages() {
        wm_core_kept=1
        sbar_core_kept=1
        theme_core_kept=1
    }
    prompt_yes_no() { return 0; }

    gum_picker

    [ "$flg_Packages" -eq 1 ]
    [ "$brew_theme" -eq 1 ]
    [ "$flg_Theme" -eq 1 ]
    [ "$brew_cli" -eq 0 ]
}

@test "gum_picker skips the theme step when tinty is pruned away" {
    reset_flags
    gum() {
        case "$*" in
            *"What should roost set up"*) printf 'Theming (tinty + auto light/dark)\n' ;;
            *) printf '' ;;
        esac
    }
    select_packages() {
        wm_core_kept=1
        sbar_core_kept=1
        theme_core_kept=0
    }
    prompt_yes_no() { return 0; }

    gum_picker

    [ "$brew_theme" -eq 1 ]
    [ "$flg_Theme" -eq 0 ]
}

@test "dry-run plan mentions the theme step" {
    run bash -c '
        cd "'"${BATS_TEST_DIRNAME}"'/.."
        source scripts/install.sh
        reset_flags
        parse_args --theme
        resolve_brew_groups
        need_pre=1
        describe_plan
    '
    [ "$status" -eq 0 ]
    [[ "${output}" == *"install_theme.sh"* ]]
}
