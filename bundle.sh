#!/bin/bash
set -e

echo "=== Building Notepad++ for Mac (Release) ==="
swift build -c release

APP_DIR="build/Notepad++.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "Copying binary..."
cp ".build/release/NotepadPlusPlusMac" "$MACOS_DIR/Notepad++"
chmod +x "$MACOS_DIR/Notepad++"

echo "Generating AppIcon.icns..."
ICONSET_DIR="build/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Extract base PNG from upstream Notepad++ icon
sips -s format png upstream_npp/PowerEditor/src/icons/npp.ico --out "$ICONSET_DIR/icon_256x256.png" >/dev/null

sips -z 16 16     "$ICONSET_DIR/icon_256x256.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32     "$ICONSET_DIR/icon_256x256.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$ICONSET_DIR/icon_256x256.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64     "$ICONSET_DIR/icon_256x256.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$ICONSET_DIR/icon_256x256.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256   "$ICONSET_DIR/icon_256x256.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$ICONSET_DIR/icon_256x256.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512   "$ICONSET_DIR/icon_256x256.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "Generating Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Notepad++</string>
    <key>CFBundleIdentifier</key>
    <string>org.notepad-plus-plus.mac</string>
    <key>CFBundleName</key>
    <string>Notepad++</string>
    <key>CFBundleDisplayName</key>
    <string>Notepad++</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>8.9.8.1</string>
    <key>CFBundleVersion</key>
    <string>8.9.8.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Text Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.text</string>
                <string>public.plain-text</string>
                <string>public.source-code</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "=== Notepad++.app successfully built at $APP_DIR ==="
