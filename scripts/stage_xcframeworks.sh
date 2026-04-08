#!/bin/bash
set -euo pipefail

MODULES=(
  "AppBoxPushSDK"
  "AppBoxHealthSDK"
  "AppBoxSnsLoginSDK"
)

usage() {
  cat <<'EOF'
Usage:
  ./scripts/stage_xcframeworks.sh [options]

Stages XCFramework artifacts from repo A into repo B.

Options:
  --source-root DIR   Root directory that contains <Module>/<Module>.xcframework.
                      Default:
                      ../appBox/waveAppSuite/build/binary_sdks
  --zip-dir DIR       Optional output directory for <Module>.xcframework.zip files.
                      When provided, the script also computes checksums.
  --only MODULE       Stage only one module. Allowed values:
                      AppBoxPushSDK, AppBoxHealthSDK, AppBoxSnsLoginSDK
  -h, --help          Show this help message.

Examples:
  ./scripts/stage_xcframeworks.sh
  ./scripts/stage_xcframeworks.sh --only AppBoxPushSDK
  ./scripts/stage_xcframeworks.sh --zip-dir ReleaseArtifacts
EOF
}

contains_module() {
  local candidate="$1"
  local item
  for item in "${MODULES[@]}"; do
    if [ "$item" = "$candidate" ]; then
      return 0
    fi
  done
  return 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_SOURCE_ROOT="$(cd "$ROOT_DIR/../appBox/waveAppSuite/build/binary_sdks" 2>/dev/null && pwd || true)"

SOURCE_ROOT="${DEFAULT_SOURCE_ROOT}"
ZIP_DIR=""
SELECTED_MODULES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --source-root)
      SOURCE_ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    --zip-dir)
      if [[ "$2" = /* ]]; then
        ZIP_DIR="$2"
      else
        ZIP_DIR="$ROOT_DIR/$2"
      fi
      shift 2
      ;;
    --only)
      if ! contains_module "$2"; then
        echo "❌ Unknown module: $2"
        usage
        exit 1
      fi
      SELECTED_MODULES=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "❌ Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [ -z "$SOURCE_ROOT" ] || [ ! -d "$SOURCE_ROOT" ]; then
  echo "❌ Source root not found: ${SOURCE_ROOT:-<empty>}"
  exit 1
fi

if [ "${#SELECTED_MODULES[@]}" -eq 0 ]; then
  SELECTED_MODULES=("${MODULES[@]}")
fi

if [ -n "$ZIP_DIR" ]; then
  mkdir -p "$ZIP_DIR"
  CHECKSUM_FILE="$ZIP_DIR/checksums.txt"
  : > "$CHECKSUM_FILE"
fi

echo "Staging XCFramework artifacts"
echo "Repo B root : $ROOT_DIR"
echo "Source root : $SOURCE_ROOT"
if [ -n "$ZIP_DIR" ]; then
  echo "Zip output  : $ZIP_DIR"
fi
echo

for module in "${SELECTED_MODULES[@]}"; do
  source_path="$SOURCE_ROOT/$module/$module.xcframework"
  target_dir="$ROOT_DIR/Sources/$module"
  target_path="$target_dir/$module.xcframework"

  if [ ! -d "$source_path" ]; then
    echo "❌ Missing source artifact: $source_path"
    exit 1
  fi

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  rm -rf "$target_path"
  cp -R "$source_path" "$target_path"
  echo "OK   staged $module -> Sources/$module/$module.xcframework"

  if [ -n "$ZIP_DIR" ]; then
    zip_path="$ZIP_DIR/$module.xcframework.zip"
    rm -f "$zip_path"
    ditto -c -k --sequesterRsrc --keepParent "$target_path" "$zip_path"
    checksum="$(swift package compute-checksum "$zip_path")"
    echo "$module $checksum" >> "$CHECKSUM_FILE"
    echo "OK   zipped  $module -> $zip_path"
    echo "OK   checksum $module -> $checksum"
  fi
done

echo
"$SCRIPT_DIR/verify_binary_distribution.sh" --strict
