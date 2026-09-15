setup() {
    cd "${BATS_TEST_DIRNAME}/.."
    YABAIRC="configs/yabai/yabairc"
}

@test "yabairc parses as sh" {
    sh -n "${YABAIRC}"
}

@test "every yabai -m call names a real domain (settings need 'config')" {
    run grep -nE '^[[:space:]]*yabai -m [a-z_]+' "${YABAIRC}"
    [ "$status" -eq 0 ]
    bad="$(printf '%s\n' "${output}" | grep -vE 'yabai -m (config|rule|signal|query|window|space|display) ' || true)"
    [ -z "${bad}" ]
}

@test "yabairc sets no option yabai does not have" {
    ! grep -q 'auto_padding' "${YABAIRC}"
}
