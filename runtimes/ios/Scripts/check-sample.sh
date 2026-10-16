#!/usr/bin/env bash
# Builds a sample app against OpenKit, plays its session.txt through the stdout renderer, prints
# the frames and checks every `# expect <text>` line in the session against the frame of the
# command above it. Needs Swift 6.4.1, Scripts/fetch-openswiftui.sh, the render core
# (`cargo build -p irisrun-render --release`) and its fonts (crates/render/fetch-fonts.sh).
#
#   Scripts/check-sample.sh [<example-dir>] [swift build options...]
#
# The example is examples/ios-swiftui unless given, such as examples/ios-uikit. With
# IRISRUN_FRAMES=<dir> the app draws through the render core instead, still prints each frame,
# and writes it to <dir> as a PNG. `# expect frame "<text>" x:16.0 y:12.0 w:358.0 h:26.3` checks
# where the view with that text is, in its superview, as the frame prints it.
set -euo pipefail

ios="$(cd "$(dirname "$0")/.." && pwd)"
examples="$ios/../../examples/ios-swiftui"
if [ $# -gt 0 ] && [ -d "$1" ]; then
    examples="$(cd "$1" && pwd)"
    shift
fi
bin="$("$ios/Scripts/compile-app.sh" "$examples" "$@")"
frames="$("$bin" < "$examples/session.txt")"
echo "$frames"

awk -v session="$examples/session.txt" '
BEGIN {
    while ((getline line < session) > 0) {
        if (line ~ /^# expect /) {
            sub(/^# expect /, "", line)
            want[++wanted] = line
            at[wanted] = commands
        } else if (line !~ /^#/ && line ~ /[^ ]/) {
            commands++
        }
    }
}
/^> / { frame++; next }
{ text[frame] = text[frame] "\n" $0 }
END {
    for (i = 1; i <= wanted; i++) {
        if (want[i] ~ /^frame "/) {
            # A line with the text in quotes and the frame after the class name.
            rest = substr(want[i], 8)
            name = substr(rest, 1, index(rest, "\"") - 1)
            geometry = substr(rest, index(rest, "\"") + 2)
            count = split(text[at[i]], lines, "\n")
            found = 0
            for (j = 1; j <= count; j++) {
                if (index(lines[j], "\"" name "\"") && index(lines[j], " " geometry " ")) found = 1
            }
            if (!found) {
                printf "FAIL: frame %d has no \"%s\" at %s\n", at[i], name, geometry
                failed = 1
            }
        } else if (index(text[at[i]], "\"" want[i] "\"") == 0) {
            printf "FAIL: frame %d has no text \"%s\"\n", at[i], want[i]
            failed = 1
        }
    }
    if (!failed) printf "ok: %d checks\n", wanted
    exit failed
}' <<< "$frames"
