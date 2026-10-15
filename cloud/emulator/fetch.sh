#!/bin/bash
# Downloads the emulator and the Android 16 (API 36) system image into downloads/,
# the Docker build context, checked against the SHA-1 in Google's repository XML
# (dl.google.com/android/repository/repository2-3.xml and sys-img/android/sys-img2-3.xml).
# The image has no Google Play: the cloud tier ships AOSP images only.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p downloads

fetch() { # file sha1 base-url
  if echo "$2  downloads/$1" | sha1sum -c --status 2>/dev/null; then return; fi
  curl -fSL --retry 10 -C - -o "downloads/$1" "$3/$1"
  echo "$2  downloads/$1" | sha1sum -c
}

fetch emulator-linux_x64-16428233.zip cd7362ea55dfb86a418958138dc396e74165dd01 https://dl.google.com/android/repository
fetch x86_64-36_r02.zip 829c076e8ff448a336097ae25a355b495ba36e2c https://dl.google.com/android/repository/sys-img/android
