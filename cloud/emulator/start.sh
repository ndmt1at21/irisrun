#!/bin/bash
# Boots one headless emulator on the host's KVM and exposes its adb on port 5556,
# since the emulator itself only listens on localhost.
set -euo pipefail

avd=$HOME/.android/avd
mkdir -p "$avd/iris.avd"
cat > "$avd/iris.ini" <<INI
avd.ini.encoding=UTF-8
path=$avd/iris.avd
target=android-36
INI
# A 1080 × 2400 phone at 420 dpi, close to Robolectric's default screen.
cat > "$avd/iris.avd/config.ini" <<INI
image.sysdir.1=system-images/android-36/default/x86_64/
tag.id=default
abi.type=x86_64
hw.cpu.arch=x86_64
hw.cpu.ncore=${EMULATOR_CORES:-2}
hw.ramSize=${EMULATOR_RAM_MB:-2048}
hw.lcd.width=1080
hw.lcd.height=2400
hw.lcd.density=420
hw.keyboard=yes
hw.gpu.enabled=yes
hw.gpu.mode=swiftshader_indirect
disk.dataPartition.size=4G
INI

socat TCP-LISTEN:5556,fork,reuseaddr TCP:127.0.0.1:5555 &
exec /opt/android/emulator/emulator -avd iris -no-window -no-audio -no-boot-anim -no-snapshot \
  -gpu swiftshader_indirect -ports 5554,5555 "$@"
