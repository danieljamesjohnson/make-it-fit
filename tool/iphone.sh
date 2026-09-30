#!/usr/bin/env bash
# Run Make It Fit on a plugged-in iPhone from the Mac.
#
#   git clone https://github.com/danieljamesjohnson/make-it-fit.git && cd make-it-fit
#   bash tool/iphone.sh            # builds and installs on the first iPhone Flutter sees
#
# First time only: Xcode needs a signing team. Open ios/Runner.xcworkspace once, select the
# Runner target > Signing & Capabilities, tick "Automatically manage signing" and pick your
# Apple ID team (free personal team is fine). Then on the phone: Settings > General > VPN &
# Device Management > trust the developer profile.
set -euo pipefail
export PATH="$HOME/development/flutter-stable/bin:/opt/homebrew/bin:$PATH"
cd "$(dirname "$0")/.."
flutter pub get
DEVICE="${1:-$(flutter devices --machine | python3 -c '
import json,sys
d=[x for x in json.load(sys.stdin) if x.get("targetPlatform","").startswith("ios") and not x.get("emulator")]
print(d[0]["id"] if d else "")')}"
if [ -z "$DEVICE" ]; then
  echo "No iPhone found. Plug it in, unlock it, tap Trust, then run again." >&2
  flutter devices >&2
  exit 1
fi
echo "Running on $DEVICE (release build, real encoder)"
exec flutter run --release -d "$DEVICE"
