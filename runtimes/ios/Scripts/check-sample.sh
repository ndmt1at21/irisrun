#!/usr/bin/env bash
# Builds examples/ios-swiftui/IrisSample against OpenKit, plays session.txt through the stdout
# renderer, prints the frames and checks every `# expect <text>` line in the session against
# the frame of the command above it. Needs Swift 6.4.1, Scripts/fetch-openswiftui.sh, the render
# core (`cargo build -p irisrun-render --release`) and its fonts (crates/render/fetch-fonts.sh).
#
# With IRISRUN_FRAMES=<dir> the app draws through the render core instead, still prints each
# frame, and writes it to <dir> as a PNG.
set -euo pipefail

ios="$(cd "$(dirname "$0")/.." && pwd)"
examples="$ios/../../examples/ios-swiftui"
bin="$("$ios/Scripts/compile-app.sh" "$examples/IrisSample" "$@")"
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
        if (index(text[at[i]], "\"" want[i] "\"") == 0) {
            printf "FAIL: frame %d has no text \"%s\"\n", at[i], want[i]
            failed = 1
        }
    }
    if (!failed) printf "ok: %d checks\n", wanted
    exit failed
}' <<< "$frames"
