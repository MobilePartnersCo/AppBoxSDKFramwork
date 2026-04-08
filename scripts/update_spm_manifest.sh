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
  ./scripts/update_spm_manifest.sh --mode path|url [options]

Updates repo B Package.swift binaryTarget declarations for the migrated modules.

Options:
  --mode MODE        path or url.
  --base-url URL     Required for --mode url.
                      Example: https://example.com/releases/1.2.2
  --zip-dir DIR      Directory that contains <Module>.xcframework.zip files.
                      Required for --mode url.
  --package-file     Package.swift path. Default: ./Package.swift
  --skip-validate    Skip 'swift package dump-package' validation.
  -h, --help         Show this help message.

Examples:
  ./scripts/update_spm_manifest.sh --mode path
  ./scripts/update_spm_manifest.sh --mode url \
    --base-url https://example.com/releases/1.2.2 \
    --zip-dir ReleaseArtifacts
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_FILE="$ROOT_DIR/Package.swift"
MODE=""
BASE_URL=""
ZIP_DIR=""
VALIDATE=1

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --base-url)
      BASE_URL="$2"
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
    --package-file)
      PACKAGE_FILE="$2"
      shift 2
      ;;
    --skip-validate)
      VALIDATE=0
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

if [ "$MODE" != "path" ] && [ "$MODE" != "url" ]; then
  echo "❌ --mode must be 'path' or 'url'"
  exit 1
fi

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "❌ Package file not found: $PACKAGE_FILE"
  exit 1
fi

if [ "$MODE" = "url" ]; then
  if [ -z "$BASE_URL" ]; then
    echo "❌ --base-url is required for url mode"
    exit 1
  fi
  if [ -z "$ZIP_DIR" ] || [ ! -d "$ZIP_DIR" ]; then
    echo "❌ --zip-dir is required for url mode"
    exit 1
  fi
fi

if [ "$MODE" = "url" ]; then
  declare -A CHECKSUMS=()
  for module in "${MODULES[@]}"; do
    zip_path="$ZIP_DIR/$module.xcframework.zip"
    if [ ! -f "$zip_path" ]; then
      echo "❌ Missing zip artifact for $module: $zip_path"
      exit 1
    fi
    CHECKSUMS["$module"]="$(swift package compute-checksum "$zip_path")"
  done
fi

CHECKSUM_FILE=""
if [ "$MODE" = "url" ]; then
  CHECKSUM_FILE="$(mktemp)"
  : > "$CHECKSUM_FILE"
  for module in "${MODULES[@]}"; do
    echo "$module ${CHECKSUMS[$module]}" >> "$CHECKSUM_FILE"
  done
fi

cleanup() {
  if [ -n "$CHECKSUM_FILE" ] && [ -f "$CHECKSUM_FILE" ]; then
    rm -f "$CHECKSUM_FILE"
  fi
}
trap cleanup EXIT

MODULES_CSV="$(IFS=,; echo "${MODULES[*]}")"
BASE_URL_TRIMMED="${BASE_URL%/}"

MODE="$MODE" \
PACKAGE_FILE="$PACKAGE_FILE" \
MODULES_CSV="$MODULES_CSV" \
BASE_URL_TRIMMED="$BASE_URL_TRIMMED" \
CHECKSUM_FILE="$CHECKSUM_FILE" \
ruby <<'RUBY'
package_file = ENV.fetch("PACKAGE_FILE")
mode = ENV.fetch("MODE")
modules = ENV.fetch("MODULES_CSV").split(",")
base_url = ENV.fetch("BASE_URL_TRIMMED", "")
checksum_file = ENV.fetch("CHECKSUM_FILE", "")

checksums = {}
if mode == "url" && !checksum_file.empty?
  File.readlines(checksum_file, chomp: true).each do |line|
    module_name, checksum = line.split(" ", 2)
    checksums[module_name] = checksum
  end
end

content = File.read(package_file)
lines = content.lines
result = []
i = 0
updated_modules = []

while i < lines.length
  current_line = lines[i]
  next_line = lines[i + 1]
  if current_line.include?(".binaryTarget(") && next_line && next_line =~ /name:\s*"([^"]+)"/
    module_name = Regexp.last_match(1)
    if modules.include?(module_name)
      replacement_lines =
        if mode == "path"
          [
            "        .binaryTarget(\n",
            "            name: \"#{module_name}\",\n",
            "            path: \"./Sources/#{module_name}/#{module_name}.xcframework\"\n",
            "        ),\n"
          ]
        else
          checksum = checksums.fetch(module_name)
          [
            "        .binaryTarget(\n",
            "            name: \"#{module_name}\",\n",
            "            url: \"#{base_url}/#{module_name}.xcframework.zip\",\n",
            "            checksum: \"#{checksum}\"\n",
            "        ),\n"
          ]
        end

      result.concat(replacement_lines)
      updated_modules << module_name
      i += 1
      while i < lines.length
        break if lines[i].strip == "),"
        i += 1
      end
      i += 1
      next
    end
  end

  result << current_line
  i += 1
end

missing = modules - updated_modules
abort("Failed to update binaryTarget for #{missing.join(', ')}") unless missing.empty?

File.write(package_file, result.join)
RUBY

echo "Updated Package.swift in $MODE mode"
if [ "$MODE" = "url" ]; then
  echo "Base URL: ${BASE_URL%/}"
fi

if [ "$VALIDATE" -eq 1 ]; then
  (
    cd "$ROOT_DIR"
    swift package dump-package >/dev/null
  )
  echo "Manifest validation passed"
fi
