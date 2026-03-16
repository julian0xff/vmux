#!/bin/bash
# Rebuild and restart vmux app

set -e

cd "$(dirname "$0")/.."

# Kill existing app if running
pkill -9 -f "vmux" 2>/dev/null || true

# Build
swift build

# Copy to app bundle
cp .build/debug/vmux .build/debug/vmux.app/Contents/MacOS/

# Open the app
open .build/debug/vmux.app
