#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🎯 Building FocusMode...${NC}"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Clean previous build
rm -rf .build/release 2>/dev/null || true
rm -rf build 2>/dev/null || true
mkdir -p build

# Build release binary
echo -e "${YELLOW}→ Compiling Swift...${NC}"
swift build -c release

# Create app bundle
echo -e "${YELLOW}→ Creating app bundle...${NC}"
APP_BUNDLE="build/FocusMode.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp .build/release/FocusMode "$APP_BUNDLE/Contents/MacOS/FocusMode"
chmod +x "$APP_BUNDLE/Contents/MacOS/FocusMode"

# Copy Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FocusMode</string>
    <key>CFBundleIdentifier</key>
    <string>com.focusmode.app</string>
    <key>CFBundleName</key>
    <string>FocusMode</string>
    <key>CFBundleDisplayName</key>
    <string>FocusMode</string>
    <key>CFBundleVersion</key>
    <string>1.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 FocusMode. MIT License.</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
EOF

# Generate icon if needed
if [ ! -f "Assets/AppIcon.icns" ]; then
    echo -e "${YELLOW}→ Generating app icon...${NC}"
    swift Scripts/generate_icon.swift
    iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
fi

# Copy icon
cp Assets/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Remove quarantine attribute
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

echo -e "${GREEN}✓ App bundle created at: $APP_BUNDLE${NC}"

# Create DMG
echo -e "${YELLOW}→ Creating DMG installer...${NC}"

DMG_NAME="FocusMode-1.1.0.dmg"
DMG_PATH="build/$DMG_NAME"
DMG_TEMP="build/dmg_temp"

# Clean up any previous DMG work
rm -rf "$DMG_TEMP" 2>/dev/null || true
rm -f "$DMG_PATH" 2>/dev/null || true

# Create temporary DMG directory
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create symlink to Applications
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create -volname "FocusMode" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP"

echo -e "${GREEN}✓ DMG created at: $DMG_PATH${NC}"
echo ""
echo -e "${GREEN}🎉 Build complete!${NC}"
echo -e "   App: build/FocusMode.app"
echo -e "   DMG: build/$DMG_NAME"
