#!/bin/bash
set -euo pipefail

STRICT=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/verify_binary_distribution.sh [--strict]

Checks whether the expected binary artifact layout is present.
By default the script reports missing artifacts and exits 0.
Use --strict to fail when one or more artifacts are missing.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --strict)
      STRICT=1
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
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ARTIFACTS=(
  "Sources/AppBoxPushSDK/AppBoxPushSDK.xcframework"
  "Sources/AppBoxHealthSDK/AppBoxHealthSDK.xcframework"
  "Sources/AppBoxSnsLoginSDK/AppBoxSnsLoginSDK.xcframework"
)

missing=()

echo "AppBox binary distribution layout check"
echo "Root: $ROOT_DIR"
echo

for artifact in "${ARTIFACTS[@]}"; do
  absolute_path="$ROOT_DIR/$artifact"
  if [ -d "$absolute_path" ]; then
    echo "OK   $artifact"
  else
    echo "MISS $artifact"
    missing+=("$artifact")
  fi
done

echo

if [ "${#missing[@]}" -eq 0 ]; then
  echo "All expected binary artifact paths are present."
  exit 0
fi

echo "Missing artifacts:"
for artifact in "${missing[@]}"; do
  echo "  - $artifact"
done

if [ "$STRICT" -eq 1 ]; then
  exit 1
fi

echo "Continuing with exit 0 because --strict was not provided."
exit 0
