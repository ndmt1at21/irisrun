#!/usr/bin/env bash
# Checks out OpenSwiftUI and the OpenSwiftUIProject packages it builds against side by side, pinned,
# and applies Patches/<package>/*.patch on top as commits. Scripts/env.sh points every manifest at
# these checkouts (OPENSWIFTUI_USE_LOCAL_DEPS=1) instead of their `main` branches.
#
# The SHAs are upstream OpenSwiftUI 0.23.1, the sibling revisions from its Package.resolved, and
# Compute 0.6.0-bugfix.1: 0.6.0, the version OpenAttributeGraph asks for, with partial value
# comparisons fixed (they read enums at the wrong offset and crashed views with `if`/`else`). Once github.com/irisrun/OpenSwiftUI exists,
# point the OpenSwiftUI line at the fork commit that carries Patches/openswiftui and delete that
# directory.
#
# To change a patch: edit and commit in the checkout, then regenerate the directory, for example
#   git -C "$IRISRUN_IOS_WORK/checkouts/OpenSwiftUI" format-patch --no-signature --zero-commit \
#     -o Patches/openswiftui 9a26fd83
set -euo pipefail

ios="$(cd "$(dirname "$0")/.." && pwd)"
source "$ios/Scripts/env.sh"
checkouts="$IRISRUN_IOS_WORK/checkouts"

pins="
OpenSwiftUI        https://github.com/OpenSwiftUIProject/OpenSwiftUI        9a26fd8385128d09e049200208091919b6b7ef78
OpenAttributeGraph https://github.com/OpenSwiftUIProject/OpenAttributeGraph 46f2e1b832fa9626bd88f62ba34ba0b799b5206c
OpenCoreGraphics   https://github.com/OpenSwiftUIProject/OpenCoreGraphics   df5ab4c4dcd0afc8fde978f6a0ad5228bb8aee17
OpenObservation    https://github.com/OpenSwiftUIProject/OpenObservation    51c52f318eb3278b1eaa8b724f50d1af9f9f8bae
OpenRenderBox      https://github.com/OpenSwiftUIProject/OpenRenderBox      7a85270fd79295c86aaf8cd578168895befd07da
Compute            https://github.com/OpenSwiftUIProject/Compute            212355dc880ad76731999cc27190c31629f486e9
"

# GitHub drops connections often on this network.
retry() {
    local n
    for n in 1 2 3 4 5; do
        "$@" && return 0
        echo "retrying ($n): $*" >&2
        sleep $((n * 5))
    done
    return 1
}

mkdir -p "$checkouts"
while read -r name url rev; do
    [ -n "$name" ] || continue
    dir="$checkouts/$name"
    patches=("$ios/Patches/${name,,}"/*.patch)
    [ -e "${patches[0]}" ] || patches=()
    stamp="$(cat /dev/null "${patches[@]}" | sha256sum | cut -c1-16)"
    if [ -e "$dir/.git" ]; then
        if [ "$(cat "$dir/.git/irisrun-patches" 2>/dev/null)" != "$stamp" ]; then
            echo "warning: Patches/${name,,} changed since $name was fetched; delete $dir and run again" >&2
        fi
        continue
    fi
    echo "fetching $name @ ${rev:0:7}"
    git init -q "$dir"
    retry git -C "$dir" fetch -q --depth 1 "$url" "$rev"
    git -C "$dir" checkout -q FETCH_HEAD
    retry git -C "$dir" submodule -q update --init --depth 1
    if [ ${#patches[@]} -gt 0 ]; then
        git -C "$dir" -c user.name=irisrun -c user.email=irisrun@localhost am -q --committer-date-is-author-date "${patches[@]}"
    fi
    echo "$stamp" > "$dir/.git/irisrun-patches"
done <<< "$pins"
