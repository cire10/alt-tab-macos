# AltTab (Optimized Community Fork)

[![Build and Release AltTab](https://github.com/cire10/alt-tab-macos/actions/workflows/build_release.yml/badge.svg)](https://github.com/cire10/alt-tab-macos/actions/workflows/build_release.yml)

This is a high-performance community fork of [AltTab for macOS](https://github.com/lwouis/alt-tab-macos) by Louis Pontoise ([@lwouis](https://github.com/lwouis)), licensed under the **GNU General Public License v3.0 (GPLv3)**.

---

## Key Improvements in this Fork

1. **⚡ Adaptive Thumbnail Memory Scaling**:
   - Window screenshots are proportionally downscaled to switcher tile dimensions immediately upon capture, and raw full-resolution display buffers are discarded off-main thread.
   - Memory usage scales with switcher UI preview dimensions rather than full native display resolution, eliminating extreme memory growth on high-density (Retina / 4K / 5K) displays.

2. **🔓 All Features Unlocked**:
   - Native, permanent access to all appearance styles (**App Icons & Titles**, **Auto Size**, **Search in Switcher**, **Extra Shortcuts**, and custom appearance overrides) without paywalls or license gating.

3. **🛡️ Streamlined, Loop-Free Permissions**:
   - Clean single-prompt flow on first launch.
   - Dismissing or denying permission does **not** cause infinite restart loops or force-quit the application.
   - Replaced intrusive polling with silent preflight checks (`CGPreflightScreenCaptureAccess`).

4. **🚫 Stripped Marketing & Upgrade Popovers**:
   - Completely disabled scheduled popovers, trial timers, hard-gate dialogs, and upgrade marketing badges.

---

## 🚀 Quick Start & Installation

### Option 1: Automated One-Command Installer (Recommended)

Run the included installer script from the root of the repository:

```bash
./scripts/install.sh
```

**For automated AI agents or non-interactive execution:**
```bash
./scripts/install.sh -y --reset-permissions
```

> **What the installer does:**
> 1. Gracefully stops any existing `AltTab` process.
> 2. Checks if an official/existing `/Applications/AltTab.app` is already installed.
> 3. Prompts the user before replacing (or auto-replaces in `-y` mode with a backup to `/Applications/AltTab.backup.app`).
> 4. Resets macOS TCC permissions cache if requested (`--reset-permissions`) to eliminate permission conflicts between official Developer-ID builds and local ad-hoc builds.
> 5. Builds the optimized binary and installs it directly to `/Applications/AltTab.app`.
> 6. Launches the application.

---

### Option 2: Pre-Built Release Download

Download the latest pre-compiled archive from GitHub Releases:
- **Download**: [Latest AltTab Release (ZIP)](https://github.com/cire10/alt-tab-macos/releases/latest)
- Unzip and drag `AltTab.app` into your `/Applications` directory.

---

## 🤖 Instructions for AI Agents & Developers

If you are an AI coding assistant (e.g. Antigravity, Claude, Copilot, Cursor) tasked with building and deploying this repository end-to-end on a macOS system, follow these exact steps:

### 1. Prerequisites Check
Ensure Xcode or Command Line Tools are active:
```bash
xcode-select -p
```

### 2. Clean Build & Deploy
To compile from source and install to `/Applications`:
```bash
# 1. Kill any existing instance
pkill -f AltTab || true

# 2. Reset permissions cache to prevent code-signature mismatch loops (if replacing another build)
tccutil reset Accessibility com.lwouis.alt-tab-macos
tccutil reset ScreenCapture com.lwouis.alt-tab-macos

# 3. Build with Xcode
xcodebuild -scheme Debug -configuration Debug CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build

# 4. Copy built app to /Applications
rm -rf /Applications/AltTab.app
cp -R ~/Library/Developer/Xcode/DerivedData/alt-tab-macos-*/Build/Products/Debug/AltTab.app /Applications/AltTab.app

# 5. Launch
open /Applications/AltTab.app
```

### 3. Running Unit Tests
To run the full unit test suite (934+ tests):
```bash
xcodebuild test -scheme Test -destination 'platform=macOS'
```

---

## 📄 Licensing & Attribution

This project is licensed under the terms of the **GNU General Public License v3.0 (GPLv3)**.
- See [`LICENCE.md`](LICENCE.md) for the complete license text.
- Original project by Louis Pontoise: [https://github.com/lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos)
