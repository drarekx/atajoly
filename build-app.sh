#!/bin/zsh
# Builds Atajoly.app (release, universal) into ./build
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Atajoly.app
VERSION=${VERSION:-1.0.0}
BUILD=${BUILD:-1}
swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Atajoly

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Atajoly"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Atajoly</string>
    <key>CFBundleIdentifier</key><string>com.egluu.atajoly</string>
    <key>CFBundleName</key><string>Atajoly</string>
    <key>CFBundleDisplayName</key><string>Atajoly</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
(cd build && rm -f Atajoly.zip && ditto -c -k --keepParent Atajoly.app Atajoly.zip)
echo "Built $APP ($VERSION) and build/Atajoly.zip"
