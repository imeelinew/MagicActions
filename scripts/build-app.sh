#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData"
DIST_DIR="$ROOT_DIR/.build/dist"
APP_NAME="MagicActions"
APP_DIR="$DIST_DIR/$APP_NAME.app"

cd "$ROOT_DIR"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CURRENT_PROJECT_VERSION=$(date +%Y%m%d%H%M) \
  build

rm -rf "$APP_DIR"
mkdir -p "$DIST_DIR"
ditto "$DERIVED_DATA_DIR/Build/Products/Release/$APP_NAME.app" "$APP_DIR"

codesign --verify --deep --strict "$APP_DIR"

echo
echo "Built: $APP_DIR"
