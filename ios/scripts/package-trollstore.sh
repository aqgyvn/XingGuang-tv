#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: package-trollstore.sh <app-path> <output-ipa>" >&2
  exit 2
fi

APP_PATH="$1"
OUTPUT_IPA="$2"

if [[ ! -d "$APP_PATH" ]]; then
  echo "app bundle not found: $APP_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_IPA")"
OUTPUT_IPA="$(cd "$(dirname "$OUTPUT_IPA")" && pwd)/$(basename "$OUTPUT_IPA")"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ -d "$APP_PATH/Frameworks" ]]; then
  while IFS= read -r -d '' framework; do
    /usr/bin/codesign --force --sign - "$framework"
  done < <(/usr/bin/find "$APP_PATH/Frameworks" -type d -name '*.framework' -print0)
fi

/usr/bin/codesign --force --sign - "$APP_PATH"
/usr/bin/codesign --verify --deep --strict "$APP_PATH"

mkdir -p "$WORK_DIR/Payload"
/usr/bin/ditto "$APP_PATH" "$WORK_DIR/Payload/$(basename "$APP_PATH")"
(
  cd "$WORK_DIR"
  /usr/bin/zip -qry "$OUTPUT_IPA" Payload
)
/usr/bin/unzip -tq "$OUTPUT_IPA"

echo "created $OUTPUT_IPA"
