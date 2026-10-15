#!/usr/bin/env bash
# Select the newest non-beta Xcode on the runner.
set -euo pipefail
ls -d /Applications/Xcode*.app || true
X=$(ls -d /Applications/Xcode_*.app 2>/dev/null | grep -v -i beta | sort -V | tail -1 || true)
if [ -n "$X" ]; then sudo xcode-select -s "$X"; fi
xcodebuild -version
