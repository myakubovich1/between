#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
BETWEEN_DEVICE=${1:-$(xcrun simctl list devices available -j | python3 -c 'import json,sys;x=json.load(sys.stdin);a=[d for k,v in x["devices"].items() if "iOS" in k for d in v if "iPhone" in d["name"]];a.sort(key=lambda d:d["state"]=="Booted",reverse=True);print(a[0]["udid"])')}
xcodebuild test -project Between.xcodeproj -scheme Between-Demo -destination "platform=iOS Simulator,id=$BETWEEN_DEVICE" -derivedDataPath work/DerivedData CODE_SIGNING_ALLOWED=NO
