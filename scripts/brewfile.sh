#!/usr/bin/env bash
# Brewfile parsing + filtering for interactive per-package selection.
#
# Packages in the Brewfile are guarded by a single group (`... if cli|apps|wm|sbar|theme`).
# These helpers are pure (awk over a Brewfile) so they can be unit-tested.

# brewfile_candidates BREWFILE GROUP
#   Emit a TSV row "type<TAB>name<TAB>spec" for every selectable brew/cask/mas
#   package whose `if` group equals GROUP. `spec` is the verbatim argument list
#   (so mas rows keep their `, id: N`).
brewfile_candidates() {
    local file=$1 group=$2
    awk -v want="${group}" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    /^(brew|cask|mas) / {
        line = $0
        hash = index(line, "#")
        code = trim((hash > 0) ? substr(line, 1, hash - 1) : line)

        type = code; sub(/ .*/, "", type)
        rest = trim(substr(code, length(type) + 1))

        cond = ""; spec = rest
        p = index(rest, " if ")
        if (p > 0) { spec = trim(substr(rest, 1, p - 1)); cond = trim(substr(rest, p + 4)) }

        name = ""
        if (match(spec, /"[^"]*"/)) name = substr(spec, RSTART + 1, RLENGTH - 2)

        n = split(cond, toks, /\|\|/)
        for (i = 1; i <= n; i++) if (trim(toks[i]) == want) {
            printf "%s\t%s\t%s\n", type, name, spec
            next
        }
    }
    ' "${file}"
}

# brewfile_generate BREWFILE CLI APPS WM SBAR THEME KEEPFILE
#   Emit a plain (unconditional) Brewfile: every tap whose condition is met by
#   the enabled groups, plus each brew/cask/mas line whose "type:name" key is
#   listed in KEEPFILE (one key per line). Group flags are "1"/"0".
brewfile_generate() {
    local file=$1 cli=$2 apps=$3 wm=$4 sbar=$5 theme=$6 keepfile=$7
    awk -v cli="${cli}" -v apps="${apps}" -v wm="${wm}" -v sbar="${sbar}" -v theme="${theme}" -v keepfile="${keepfile}" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function active(cond,   n, toks, i) {
        if (cond == "") return 1
        n = split(cond, toks, /\|\|/)
        for (i = 1; i <= n; i++) if (g[trim(toks[i])] == "1") return 1
        return 0
    }
    BEGIN {
        g["cli"] = cli; g["apps"] = apps; g["wm"] = wm; g["sbar"] = sbar; g["theme"] = theme
        while ((getline k < keepfile) > 0) keep[k] = 1
    }
    /^(tap|brew|cask|mas) / {
        line = $0
        hash = index(line, "#")
        code = trim((hash > 0) ? substr(line, 1, hash - 1) : line)

        type = code; sub(/ .*/, "", type)
        rest = trim(substr(code, length(type) + 1))

        cond = ""; spec = rest
        p = index(rest, " if ")
        if (p > 0) { spec = trim(substr(rest, 1, p - 1)); cond = trim(substr(rest, p + 4)) }

        if (!active(cond)) next
        if (type == "tap") { print type " " spec; next }

        name = ""
        if (match(spec, /"[^"]*"/)) name = substr(spec, RSTART + 1, RLENGTH - 2)
        if ((type ":" name) in keep) print type " " spec
    }
    ' "${file}"
}
