#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE_ID="com.lwouis.alt-tab-macos"
DEST_APP_PATH="/Applications/AltTab.app"
BACKUP_APP_PATH="/Applications/AltTab.backup.app"

# Flags
FORCE=false
RESET_PERMS=false

for arg in "$@"; do
    case $arg in
        -y|--yes|--force)
            FORCE=true
            ;;
        --reset-permissions)
            RESET_PERMS=true
            ;;
        -h|--help)
            echo "Usage: ./scripts/install.sh [options]"
            echo ""
            echo "Options:"
            echo "  -y, --yes              Non-interactive mode (auto-replace existing AltTab)"
            echo "  --reset-permissions    Reset macOS Accessibility & Screen Recording TCC caches"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
    esac
done

echo "========================================================"
echo "  AltTab (Optimized Lightweight Build) - Installer"
echo "========================================================"

# 1. Stop any currently running instance of AltTab
if pgrep -fi "AltTab" > /dev/null; then
    echo "==> Stopping running AltTab process..."
    pkill -f AltTab || true
    sleep 1
fi

# 2. Check for existing /Applications/AltTab.app
if [ -d "$DEST_APP_PATH" ]; then
    echo "==> Found existing installation at: $DEST_APP_PATH"
    
    if [ "$FORCE" = false ] && [ -t 0 ]; then
        read -p "Would you like to replace the existing AltTab with this optimized version? [Y/n] " response
        case "$response" in
            [nN][oO]|[nN])
                echo "Installation cancelled."
                exit 0
                ;;
            *)
                echo "Proceeding with replacement..."
                ;;
        esac
    fi

    echo "==> Backing up existing app to: $BACKUP_APP_PATH"
    rm -rf "$BACKUP_APP_PATH"
    cp -R "$DEST_APP_PATH" "$BACKUP_APP_PATH"
    rm -rf "$DEST_APP_PATH"
fi

# 3. Handle Permission Cache Reset (prevents TCC signature-mismatch loops)
if [ "$RESET_PERMS" = true ]; then
    echo "==> Resetting macOS TCC permission cache for $APP_BUNDLE_ID..."
    tccutil reset Accessibility "$APP_BUNDLE_ID" 2>/dev/null || true
    tccutil reset ScreenCapture "$APP_BUNDLE_ID" 2>/dev/null || true
fi

# 4. Build from source
echo "==> Building AltTab with Xcode..."
cd "$REPO_ROOT"
xcodebuild -scheme Debug -configuration Debug CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build > /dev/null

DERIVED_DATA_APP="$(find ~/Library/Developer/Xcode/DerivedData -name "AltTab.app" -path "*/Build/Products/Debug/AltTab.app" | head -n 1)"

if [ -z "$DERIVED_DATA_APP" ] || [ ! -d "$DERIVED_DATA_APP" ]; then
    echo "Error: Could not locate compiled AltTab.app in DerivedData."
    exit 1
fi

# 5. Copy build artifacts
mkdir -p "$REPO_ROOT/build"
rm -rf "$REPO_ROOT/build/AltTab.app"
cp -R "$DERIVED_DATA_APP" "$REPO_ROOT/build/AltTab.app"

echo "==> Installing to $DEST_APP_PATH..."
cp -R "$REPO_ROOT/build/AltTab.app" "$DEST_APP_PATH"

# 6. Launch the newly installed application
echo "==> Launching AltTab..."
open "$DEST_APP_PATH"

echo ""
echo "========================================================"
echo "  Installation Complete!"
echo "========================================================"
echo "AltTab is now running from: $DEST_APP_PATH"
echo "If prompted by macOS, allow Accessibility & Screen Recording in:"
echo "  System Settings -> Privacy & Security"
echo ""
