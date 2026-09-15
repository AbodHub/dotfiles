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
