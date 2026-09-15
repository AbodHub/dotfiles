#!/usr/bin/env bash
# tinty hook for Warp: install the rendered theme as ~/.warp/themes/tinty.yaml
# and make Warp apply it.
#
# Warp does not re-apply a selected theme when its file changes in place, but it
# re-reads settings.toml as soon as that file changes. Toggling "Sync with OS"
# in the UI rewrites settings.toml, which is why that refreshes the theme. This
# hook does the same toggle, only when Sync with OS is on with tinty selected.
#
# Usage: warp.sh <rendered-theme.yaml>

set -euo pipefail

src=$1
warp="${HOME}/.warp"
settings="${warp}/settings.toml"

# Warp has never run on this machine: nothing to theme.
[[ -d "${warp}" ]] || exit 0

# Warp keys the selection on name and path, so pin the name to "tinty".
mkdir -p "${warp}/themes"
tmp="$(mktemp "${warp}/themes/.tinty.XXXXXX")"
sed 's/^name: .*/name: tinty/' "${src}" >"${tmp}"
mv -f "${tmp}" "${warp}/themes/tinty.yaml"

grep -q '^system_theme = true$' "${settings}" 2>/dev/null || exit 0
grep -q 'path = "tinty.yaml"' "${settings}" || exit 0

restore() { sed -i '' 's/^system_theme = false$/system_theme = true/' "${settings}"; }
trap restore EXIT
sed -i '' 's/^system_theme = true$/system_theme = false/' "${settings}"
sleep "${WARP_TOGGLE_DELAY:-1}"
