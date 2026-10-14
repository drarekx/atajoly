#!/bin/bash
# Atajoly installer.
#   curl -fsSL https://raw.githubusercontent.com/drarekx/atajoly/main/install.sh | bash
set -euo pipefail

REPO="drarekx/atajoly"
URL="https://github.com/$REPO/releases/latest/download/Atajoly.zip"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
fail() { printf "\033[31mError:\033[0m %s\n" "$*" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || fail "Atajoly solo funciona en macOS."
major=$(sw_vers -productVersion | cut -d. -f1)
(( major >= 14 )) || fail "Atajoly necesita macOS 14 (Sonoma) o posterior. Tienes $(sw_vers -productVersion)."

bold "Descargando Atajoly…"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fL --progress-bar "$URL" -o "$tmp/Atajoly.zip" || fail "No se pudo descargar $URL"
ditto -x -k "$tmp/Atajoly.zip" "$tmp"
[[ -d "$tmp/Atajoly.app" ]] || fail "El archivo descargado no contiene Atajoly.app"

# Close a running copy so it can be replaced.
if pgrep -x Atajoly >/dev/null; then
    bold "Cerrando Atajoly…"
    osascript -e 'quit app "Atajoly"' 2>/dev/null || true
    sleep 1
    pkill -x Atajoly 2>/dev/null || true
fi

dest="/Applications"
if [[ ! -w "$dest" ]]; then
    dest="$HOME/Applications"
    mkdir -p "$dest"
fi
rm -rf "$dest/Atajoly.app"
mv "$tmp/Atajoly.app" "$dest/"
# The app is not notarized; skip the Gatekeeper prompt for this copy.
xattr -dr com.apple.quarantine "$dest/Atajoly.app" 2>/dev/null || true
bold "Instalado en $dest/Atajoly.app"

if pgrep -x rcmd >/dev/null; then
    echo
    echo "rcmd está abierto: los dos usan ⌘ derecho y se pisan. Ciérralo antes de usar Atajoly."
fi

open "$dest/Atajoly.app"
bold "¡Listo! Mantén ⌘ derecho y pulsa la inicial de una app."
