# One headless Android emulator for a cloud session, on the host's KVM:
#   ./fetch.sh && docker build -t irisrun-emulator:36 .
#   docker run -d --device /dev/kvm -p 127.0.0.1:15556:5556 irisrun-emulator:36
#   adb connect 127.0.0.1:15556
FROM ubuntu:24.04

# What the emulator's own libraries do not bundle.
RUN apt-get update && apt-get install -y --no-install-recommends \
      libdbus-1-3 libdrm2 libfontconfig1 libgbm1 libgl1 libnss3 libpulse0 libx11-6 libx11-xcb1 \
      libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxkbcommon0 \
      libxkbfile1 libxrender1 libxtst6 socat unzip \
    && rm -rf /var/lib/apt/lists/*

ENV ANDROID_SDK_ROOT=/opt/android ANDROID_HOME=/opt/android
# A bind mount instead of COPY, so the 1.1 GB of zips stay out of the image.
RUN --mount=type=bind,source=downloads,target=/downloads \
    mkdir -p /opt/android/system-images/android-36/default \
    && unzip -q /downloads/emulator-linux_x64-16428233.zip -d /opt/android \
    && unzip -q /downloads/x86_64-36_r02.zip -d /opt/android/system-images/android-36/default

# The emulator only takes an SDK root that has these; adb itself runs outside.
RUN mkdir -p /opt/android/platform-tools /opt/android/platforms

COPY start.sh /usr/local/bin/start-emulator
EXPOSE 5556
ENTRYPOINT ["start-emulator"]
