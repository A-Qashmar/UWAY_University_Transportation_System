FROM --platform=linux/amd64 eclipse-temurin:17.0.16_8-jdk-noble@sha256:bbc959486c469c589091571ba524e6a98f27e19bd99489c683d9b465e4f8db8d

ARG FLUTTER_VERSION=3.47.6
ARG FLUTTER_ARCHIVE_SHA256=f1631b9c2c8b3529323db412b0d1beacf4a748f8783b0d7cf599a8fd5f461675
ARG ANDROID_CMDLINE_TOOLS_BUILD=15859902
ARG ANDROID_CMDLINE_TOOLS_SHA256=4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583

ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    FLUTTER_HOME=/opt/flutter \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:$PATH \
    CI=true

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        file \
        git \
        libglu1-mesa \
        rsync \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN curl --fail --location --retry 3 \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
        --output /tmp/flutter.tar.xz \
    && echo "${FLUTTER_ARCHIVE_SHA256}  /tmp/flutter.tar.xz" | sha256sum --check --status \
    && mkdir -p /opt \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter \
    && flutter --version

RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" \
    && curl --fail --location --retry 3 \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip" \
        --output /tmp/android-command-line-tools.zip \
    && echo "${ANDROID_CMDLINE_TOOLS_SHA256}  /tmp/android-command-line-tools.zip" | sha256sum --check --status \
    && mkdir -p /tmp/android-command-line-tools \
    && unzip -q /tmp/android-command-line-tools.zip -d /tmp/android-command-line-tools \
    && mv /tmp/android-command-line-tools/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest" \
    && rm -rf /tmp/android-command-line-tools /tmp/android-command-line-tools.zip \
    && yes | sdkmanager --sdk_root="${ANDROID_HOME}" --licenses >/dev/null \
    && sdkmanager --sdk_root="${ANDROID_HOME}" \
        "platform-tools" \
        "platforms;android-36" \
        "build-tools;36.0.0" \
        "ndk;28.2.13676358"

RUN <<'EOF'
cat > /usr/local/bin/uway-build <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

source_dir="${UWAY_SOURCE_DIR:-/workspace}"
work_dir="$(mktemp -d /tmp/uway-mobile.XXXXXX)"
trap 'rm -rf "$work_dir"' EXIT

tar -C "$source_dir" \
  --exclude=.git \
  --exclude=.dart_tool \
  --exclude=build \
  --exclude=android/.gradle \
  -cf - . | tar -C "$work_dir" -xf -

cd "$work_dir"
flutter pub get
cp "$work_dir/pubspec.lock" "$source_dir/pubspec.lock"
flutter analyze
flutter build apk --debug

apk_path="$work_dir/build/app/outputs/flutter-apk/app-debug.apk"
test -s "$apk_path"
mkdir -p "$source_dir/build/app/outputs/flutter-apk"
cp "$apk_path" "$source_dir/build/app/outputs/flutter-apk/app-debug.apk"
printf '\nAPK saved to: %s/build/app/outputs/flutter-apk/app-debug.apk\n' "$source_dir"
SCRIPT
EOF
RUN chmod +x /usr/local/bin/uway-build

WORKDIR /workspace
CMD ["uway-build"]
