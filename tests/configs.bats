setup() {
    cd "${BATS_TEST_DIRNAME}/.."
}

@test "install.conf.yaml links the tmux config" {
    grep -q '~/.config/tmux: configs/tmux' install.conf.yaml
    [ -f configs/tmux/tmux.conf ]
}

@test "install.conf.yaml links the lazygit config and zshrc points lazygit at it" {
    grep -q '~/.config/lazygit: configs/lazygit' install.conf.yaml
    [ -f configs/lazygit/config.yml ]
    grep -q '^export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"$' configs/shell/zshrc
}

@test "install.conf.yaml links delta.gitconfig only when delta is installed" {
    grep -A2 '~/.config/git/delta.gitconfig:' install.conf.yaml | grep -q 'path: configs/git/delta.gitconfig'
    grep -A2 '~/.config/git/delta.gitconfig:' install.conf.yaml | grep -q 'if: command -v delta'
}

@test "git uses delta only when delta.gitconfig is linked" {
    home="${BATS_TEST_TMPDIR}/home"
    mkdir -p "${home}"
    cp configs/git/gitconfig "${home}/.gitconfig"
    gitget() { env -u GIT_CONFIG_GLOBAL HOME="${home}" XDG_CONFIG_HOME="${home}/.config" GIT_CONFIG_NOSYSTEM=1 git config --global --includes --get "$1"; }

    run gitget core.pager
    [ "$status" -eq 1 ]
    run gitget interactive.diffFilter
    [ "$status" -eq 1 ]

    mkdir -p "${home}/.config/git"
    cp configs/git/delta.gitconfig "${home}/.config/git/delta.gitconfig"
    run gitget core.pager
    [ "$output" = "delta" ]
    run gitget interactive.diffFilter
    [ "$output" = "delta --color-only" ]
}
