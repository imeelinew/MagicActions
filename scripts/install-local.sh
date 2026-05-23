#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MagicActions"
APP_SOURCE="$ROOT_DIR/.build/dist/$APP_NAME.app"
APP_DEST="$HOME/Applications/$APP_NAME.app"
EXTENSION_ID="local.elidev.MagicActions.FinderSync"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

unregister_app() {
  local app_path="$1"
  [ -d "$app_path" ] || return 0
  "$LSREGISTER" -u "$app_path" >/dev/null 2>&1 || true
  if [ -d "$app_path/Contents/PlugIns/MagicActionsFinderSync.appex" ]; then
    pluginkit -r "$app_path/Contents/PlugIns/MagicActionsFinderSync.appex" >/dev/null 2>&1 || true
  fi
}

unregister_build_products() {
  local app_path
  while IFS= read -r app_path; do
    [ "$app_path" = "$APP_DEST" ] && continue
    unregister_app "$app_path"
  done < <(
    find "$ROOT_DIR/.build" "$HOME/Library/Developer/Xcode/DerivedData" \
      -path "*/MagicActions.app" -type d -prune 2>/dev/null || true
  )
}

"$ROOT_DIR/scripts/build-app.sh"

mkdir -p "$HOME/Applications"
unregister_build_products
unregister_app "$APP_DEST"
rm -rf "$APP_DEST"
ditto "$APP_SOURCE" "$APP_DEST"

"$LSREGISTER" -f "$APP_DEST" || true

pluginkit -a "$APP_DEST/Contents/PlugIns/MagicActionsFinderSync.appex" || true
pluginkit -e use -i "$EXTENSION_ID" || true
unregister_build_products

open "$APP_DEST"

echo
echo "Installed: $APP_DEST"
echo "Extension: $EXTENSION_ID"
echo "If this is the first install, enable it in System Settings -> Privacy & Security -> Extensions -> Finder Extensions."
