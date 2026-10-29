#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/between-live-check.XXXXXX")
trap 'rm -rf "$verify_dir"' EXIT
swiftc -swift-version 6 -parse-as-library \
  "$repo_root/App/Domain/Models.swift" \
  "$repo_root/App/Services/UFLibraryData.swift" \
  "$repo_root/App/Services/StudyRooms.swift" \
  "$repo_root/scripts/verify-live-data.swift" -o "$verify_dir/verify"
"$verify_dir/verify"
