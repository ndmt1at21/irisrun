#!/usr/bin/env python3
"""Removes #Preview blocks from Swift source on stdin and writes the rest to stdout.

Previews are not part of the app and often use APIs OpenKit does not have yet. A block runs
from a line that starts with #Preview to the line where its braces balance. Braces inside
string literals on the same line are ignored; multi-line strings and comments are not
understood, which is enough for previews as Xcode writes them.

`strip-previews.py --test` runs the self-check.
"""
import re
import sys

STRING = re.compile(r'"(?:\\.|[^"\\])*"')


def strip(source):
    out, in_preview = [], False
    for line in source.splitlines(keepends=True):
        if not in_preview:
            if not line.lstrip().startswith("#Preview"):
                out.append(line)
                continue
            in_preview, depth, opened = True, 0, False
        code = STRING.sub("", line).split("//")[0]
        depth += code.count("{") - code.count("}")
        opened = opened or "{" in code
        in_preview = not (opened and depth <= 0)
    return "".join(out)


def test():
    source = (
        "import SwiftUI\n"
        "struct A: View { var body: some View { Text(\"{\") } }\n"
        "#Preview {\n"
        "    A()\n"
        "        .frame(width: 10) // }\n"
        "}\n"
        '#Preview("Dark", traits: .sizeThatFitsLayout) { A() }\n'
        "#Preview(\"Two lines\")\n"
        "{\n"
        "    A()\n"
        "}\n"
        "let b = 1\n"
    )
    expected = (
        "import SwiftUI\n"
        "struct A: View { var body: some View { Text(\"{\") } }\n"
        "let b = 1\n"
    )
    assert strip(source) == expected, strip(source)
    print("ok")


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        test()
    else:
        sys.stdout.write(strip(sys.stdin.read()))
