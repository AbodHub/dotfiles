setup() {
    cd "${BATS_TEST_DIRNAME}/.."
}

@test "install.conf.yaml links the tmux config" {
    grep -q '~/.config/tmux: configs/tmux' install.conf.yaml
    [ -f configs/tmux/tmux.conf ]
}
