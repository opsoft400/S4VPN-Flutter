#!/usr/bin/env bash
# Regenerate lib/l10n/maps.g.dart from the Persian source text.
#
# The translation tables were extracted verbatim from the UI preview
# (assets/images/S4VPN-UI.html). The preview stays in the repository on
# purpose: it is the spec this app is measured against, and this script is how
# a future change to it reaches the app.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
html="$root/assets/images/S4VPN-UI.html"
out="$root/lib/l10n/maps.g.dart"

command -v awk >/dev/null || { echo "awk is required" >&2; exit 1; }

# The three tables live between these exact anchors in the preview.
start_of() { grep -n "const $1 = {" "$html" | head -1 | cut -d: -f1; }

line_en="$(start_of EN)"
line_l="$(start_of L)"
line_d="$(start_of D)"

sed -n "${line_en},/^  };/p" "$html" > "$root/.l10n_en.js"
sed -n "${line_l},/^  };/p" "$html" > "$root/.l10n_L.js"
sed -n "${line_d},/^  };/p" "$html" > "$root/.l10n_D.js"

# Object literal of string->string pairs. Quote bare keys, keep everything
# inside quotes untouched, and drop the JS wrapper.
js2dart() {
  awk '
    BEGIN { q = sprintf("%c", 34) }
    {
      line = $0; n = length(line); out = ""; i = 1
      while (i <= n) {
        c = substr(line, i, 1)
        if (instr) {
          out = out c
          if (esc) esc = 0
          else if (c == "\\") esc = 1
          else if (c == q) instr = 0
          i++; continue
        }
        if (c == q) { instr = 1; out = out c; i++; continue }
        if (c == "{" || c == ",") {
          j = i + 1
          while (j <= n && substr(line, j, 1) ~ /[ \t]/) j++
          k = j
          while (k <= n && substr(line, k, 1) ~ /[A-Za-z_]/) k++
          if (k > j && k <= n && substr(line, k, 1) == ":") {
            out = out c q substr(line, j, k - j) q ":"
            i = k + 1
            continue
          }
        }
        out = out c; i++
      }
      print out
    }'
}

{
  cat <<'HDR'
// Generated from assets/images/S4VPN-UI.html by tool/gen_l10n.sh. Do not edit.

// ignore_for_file: prefer_single_quotes

library;

/// Persian source text -> English. English is the neutral source used for
/// every other language.
const Map<String, String> faToEn = {
HDR
  sed '1d;$d' "$root/.l10n_en.js" | js2dart
  echo "};"
  echo ""
  echo "/// English -> translation, per language. Anything missing falls back to"
  echo "/// the English string produced by [faToEn]."
  echo "const Map<String, Map<String, String>> enToLang = {"
  sed '1d;$d' "$root/.l10n_L.js" | awk '
    /^[ \t]*[a-z][a-z]:\{/ {
      code = $0; sub(/^[ \t]*/, "", code); sub(/:.*/, "", code)
      printf "  \047%s\047: {\n", code; next
    }
    /^[ \t]*},?[ \t]*$/ { print "  },"; next }
    { print }'
  echo "};"
  echo ""
  echo "/// Per-language chrome strings (nav labels, status words, options)."
  echo "const Map<String, Map<String, String>> langChrome = {"
  sed '1d;$d' "$root/.l10n_D.js" | js2dart |
    sed -E 's/^([[:space:]]*)(fa|en|zh|ja|de|ru):\{/\1\047\2\047: {/'
  echo "};"
} > "$out"

rm -f "$root/.l10n_en.js" "$root/.l10n_L.js" "$root/.l10n_D.js"
echo "wrote $out"
