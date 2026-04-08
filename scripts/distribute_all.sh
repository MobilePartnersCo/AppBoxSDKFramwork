#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/distribute_all.sh [options]

Stages XCFramework artifacts first, then updates Package.swift.

Options:
  --mode MODE        path or url. Default: path
  --source-root DIR  Passed to stage_xcframeworks.sh
  --zip-dir DIR      Passed to stage_xcframeworks.sh and update_spm_manifest.sh
  --base-url URL     Passed to update_spm_manifest.sh for url mode
  --only MODULE      Passed to stage_xcframeworks.sh
  --skip-validate    Passed to update_spm_manifest.sh
  -h, --help         Show this help message.

Examples:
  ./scripts/distribute_all.sh
  ./scripts/distribute_all.sh --mode url \
    --zip-dir ReleaseArtifacts \
    --base-url https://example.com/releases/1.2.2
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="path"
SOURCE_ROOT=""
ZIP_DIR=""
BASE_URL=""
ONLY_MODULE=""
SKIP_VALIDATE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --source-root)
      SOURCE_ROOT="$2"
      shift 2
      ;;
    --zip-dir)
      ZIP_DIR="$2"
      shift 2
      ;;
    --base-url)
      BASE_URL="$2"
      shift 2
      ;;
    --only)
      ONLY_MODULE="$2"
      shift 2
      ;;
    --skip-validate)
      SKIP_VALIDATE=1
      shift
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

STAGE_ARGS=()
MANIFEST_ARGS=(--mode "$MODE")

if [ -n "$SOURCE_ROOT" ]; then
  STAGE_ARGS+=(--source-root "$SOURCE_ROOT")
fi
if [ -n "$ZIP_DIR" ]; then
  STAGE_ARGS+=(--zip-dir "$ZIP_DIR")
  MANIFEST_ARGS+=(--zip-dir "$ZIP_DIR")
fi
if [ -n "$ONLY_MODULE" ]; then
  STAGE_ARGS+=(--only "$ONLY_MODULE")
fi
if [ -n "$BASE_URL" ]; then
  MANIFEST_ARGS+=(--base-url "$BASE_URL")
fi
if [ "$SKIP_VALIDATE" -eq 1 ]; then
  MANIFEST_ARGS+=(--skip-validate)
fi

"$SCRIPT_DIR/stage_xcframeworks.sh" "${STAGE_ARGS[@]}"
"$SCRIPT_DIR/update_spm_manifest.sh" "${MANIFEST_ARGS[@]}"

echo
echo "All distribution steps completed."
