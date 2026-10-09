#!/bin/zsh
# Dựng "Gõ Việt.app" bằng SwiftPM (không cần Xcode).
# Dùng: Tools/build_app.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Gõ Việt.app"
BUNDLE_ID="vn.goviet.GoViet"
VERSION="0.1.0"

swift build -c release --build-system native
BIN="$(swift build -c release --build-system native --show-bin-path)/GoViet"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GoViet"

# Icon
swift Tools/make_icon.swift icon.png build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Gõ Việt</string>
    <key>CFBundleDisplayName</key><string>Gõ Việt</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>GoViet</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ký ad-hoc với yêu cầu định danh cố định (theo bundle ID) để quyền Trợ năng không mất sau mỗi lần build lại.
# --options runtime (Hardened Runtime): chặn chèn thư viện (DYLD_INSERT_LIBRARIES…) để mượn quyền đọc phím của app.
codesign --force --options runtime --sign - -r="designated => identifier \"$BUNDLE_ID\"" "$APP"
echo "Đã dựng: $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x GoViet 2>/dev/null || true
    rm -rf "/Applications/Gõ Việt.app"
    cp -R "$APP" "/Applications/"
    echo "Đã cài vào /Applications"
fi
