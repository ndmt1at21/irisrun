#!/usr/bin/env bash
# Checks out OpenSwiftUI and the OpenSwiftUIProject packages it builds against side by side in
# .irisrun/checkouts, pinned, and applies Patches/openswiftui. Scripts/env.sh sets
# OPENSWIFTUI_USE_LOCAL_DEPS=1 so every manifest uses these checkouts instead of `main`.
#
# The SHAs are upstream OpenSwiftUI 0.23.1 and the sibling revisions from its Package.resolved.
# Once github.com/irisrun/OpenSwiftUI exists, point the OpenSwiftUI line at the fork commit that
# carries Patches/openswiftui and delete that directory.
set -euo pipefail

ios="$(cd "$(dirname "$0")/.." && pwd)"
checkouts="$ios/.irisrun/checkouts"

pins="
OpenSwiftUI        https://github.com/OpenSwiftUIProject/OpenSwiftUI        9a26fd8385128d09e049200208091919b6b7ef78
OpenAttributeGraph https://github.com/OpenSwiftUIProject/OpenAttributeGraph 46f2e1b832fa9626bd88f62ba34ba0b799b5206c
OpenCoreGraphics   https://github.com/OpenSwiftUIProject/OpenCoreGraphics   df5ab4c4dcd0afc8fde978f6a0ad5228bb8aee17
OpenObservation    https://github.com/OpenSwiftUIProject/OpenObservation    51c52f318eb3278b1eaa8b724f50d1af9f9f8bae
OpenRenderBox      https://github.com/OpenSwiftUIProject/OpenRenderBox      7a85270fd79295c86aaf8cd578168895befd07da
Compute            https://github.com/OpenSwiftUIProject/Compute            ef29bc336a16cee2091eb30b0a3aef606d2163d9
"

mkdir -p "$checkouts"
while read -r name url rev; do
    [ -n "$name" ] || continue
    dir="$checkouts/$name"
    if [ -e "$dir/.git" ]; then
        continue # Delete the directory to fetch it again.
    fi
    echo "fetching $name @ ${rev:0:7}"
    git init -q "$dir"
    git -C "$dir" fetch -q --depth 1 "$url" "$rev"
    git -C "$dir" checkout -q FETCH_HEAD
    git -C "$dir" submodule -q update --init --depth 1
    if [ "$name" = OpenSwiftUI ]; then
        git -C "$dir" apply "$ios"/Patches/openswiftui/*.patch
    fi
done <<< "$pins"
