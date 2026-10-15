#!/bin/sh
# Downloads the fonts OpenKit draws text with into ${IRISRUN_HOME:-~/.irisrun}/fonts.
# SF Pro cannot be used off Apple hardware, so Inter stands in for Latin,
# Vietnamese and Cyrillic, and Noto Sans SC for Chinese and Japanese kana.
# Both are under the SIL Open Font License 1.1. Pinned to a google/fonts commit.
set -eu

commit=4a943f60f1e99b2e5a2778aa34ba82adf77e4615
dir=${IRISRUN_HOME:-$HOME/.irisrun}/fonts
mkdir -p "$dir"

# macOS has shasum but not sha256sum.
check() { if command -v sha256sum >/dev/null; then sha256sum -c --status; else shasum -a 256 -c --status; fi; }

fetch() { # file path-in-repo sha256
  if [ -f "$dir/$1" ] && echo "$3  $dir/$1" | check; then return; fi
  curl -fsSL --retry 5 -o "$dir/$1.part" "https://raw.githubusercontent.com/google/fonts/$commit/$2"
  echo "$3  $dir/$1.part" | check || { echo "bad checksum: $1" >&2; exit 1; }
  mv "$dir/$1.part" "$dir/$1"
}

fetch Inter.ttf 'ofl/inter/Inter%5Bopsz,wght%5D.ttf' 29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031
fetch InterItalic.ttf 'ofl/inter/Inter-Italic%5Bopsz,wght%5D.ttf' acd98e64795781b2058f07b18475e0ecee2a0fe2b42a49e2f9e37d0d6bf66ce6
fetch NotoSansSC.ttf 'ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf' a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da
echo "$dir"
