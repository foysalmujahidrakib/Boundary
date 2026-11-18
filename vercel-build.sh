#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.41.9"
FLUTTER_DIR="/tmp/flutter"

echo "Installing Flutter ${FLUTTER_VERSION}..."

if [ ! -d "$FLUTTER_DIR" ]; then
    git clone --depth 1 \
        --branch "$FLUTTER_VERSION" \
        https://github.com/flutter/flutter.git \
        "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
export CI=true

echo "Checking Flutter version..."
flutter --version

echo "Installing dependencies..."
flutter pub get

echo "Building Boundary Flutter Web..."
flutter build web --release

echo "Flutter web build completed successfully!"
