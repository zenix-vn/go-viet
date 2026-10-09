#!/bin/zsh
# Đóng gói "GoViet.app" thành file .dmg có lối tắt tới /Applications.
# Dùng: Tools/make_dmg.sh   (tự build app trước)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"
APP="build/GoViet.app"
DMG="build/GoViet-$VERSION.dmg"
STAGE="build/dmg-stage"

Tools/build_app.sh

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Đọc trước khi cài.txt" <<TXT
CÀI ĐẶT
1. Kéo "GoViet" vào thư mục Applications.
2. Mở GoViet từ Applications. Nếu macOS báo không xác minh được nhà phát triển:
   bấm chuột phải vào ứng dụng → Mở → Mở. (Chỉ cần làm một lần.)
3. Cấp quyền Trợ năng khi ứng dụng hướng dẫn.
4. Chuyển nguồn nhập của macOS về ABC và tắt bộ gõ tiếng Việt của Apple.
5. Bấm Control + Space để chuyển Việt/Anh.
TXT

hdiutil create -volname "GoViet" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Đã tạo: $DMG ($(du -h "$DMG" | cut -f1))"
