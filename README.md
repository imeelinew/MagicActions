# MagicActions

MagicActions is a native macOS menu bar host app plus Finder Sync extension for custom Finder context-menu actions.

## Targets

- `MagicActions`: menu bar host app. It installs bundled scripts/templates into the Finder Sync Application Scripts directory and shows a minimal status-bar menu.
- `MagicActionsFinderSync`: Finder Sync extension. It exposes the `MagicActions` Finder context menu and launches action scripts with `NSUserUnixTask`.

## Build

Requirements:

- macOS 26+
- Xcode 26+
- XcodeGen, when regenerating `MagicActions.xcodeproj` from `project.yml`

Generate the Xcode project:

```bash
xcodegen generate
```

Build:

```bash
xcodebuild -project MagicActions.xcodeproj -scheme MagicActions -configuration Debug build
```

Build a local release bundle:

```bash
scripts/build-app.sh
```

Install for local use:

```bash
scripts/install-local.sh
```

On first install, enable the Finder extension in System Settings -> Privacy & Security -> Extensions -> Finder Extensions.

## Runtime Paths

- Scripts/templates: `~/Library/Application Scripts/local.elidev.MagicActions.FinderSync/`
- Script log: `~/Library/Logs/magicactions.log`
- Finder Sync log: `~/Library/Logs/magicactions-findersync.log`
