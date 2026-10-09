#!/bin/zsh
# Dựng "GoViet.app" bằng xcodebuild từ GoViet.xcodeproj (ký ad-hoc theo bundle ID, Hardened Runtime).
# Dùng: Tools/build_app.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/GoViet.app"

xcodebuild -project GoViet.xcodeproj -scheme GoViet -configuration Release \
    -derivedDataPath build/DerivedData build -quiet
rm -rf "$APP"
cp -R build/DerivedData/Build/Products/Release/GoViet.app "$APP"
echo "Đã dựng: $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x GoViet 2>/dev/null || true
    rm -rf "/Applications/Gõ Việt.app"   # tên cũ
    rm -rf "/Applications/GoViet.app"
    cp -R "$APP" "/Applications/"
    echo "Đã cài vào /Applications"
fi
