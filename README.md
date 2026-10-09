# GoViet

**GoViet** (*Gõ Việt*): bộ gõ tiếng Việt Telex cho macOS. Phát triển bởi **[Zenix Labs](https://zenix.vn/)**.

Không gạch chân, không lặp chữ. Thiết kế chi tiết: [docs/DESIGN.md](docs/DESIGN.md).

## Dựng và cài

```sh
open GoViet.xcodeproj            # mở bằng Xcode (scheme GoViet / VietEngineChecks)
swift run VietEngineChecks      # kiểm thử engine (SwiftPM, tuỳ chọn)
xcodegen generate               # sinh lại GoViet.xcodeproj từ project.yml sau khi thêm/bớt file
Tools/build_app.sh --install    # dựng và chép vào /Applications
```

Cần Swift toolchain (Command Line Tools là đủ), macOS 13 trở lên.

## Lần đầu chạy

1. Mở **GoViet**, cấp quyền **Trợ năng** trong System Settings (ứng dụng sẽ hướng dẫn).
2. Chuyển nguồn nhập của macOS về **ABC** và tắt bộ gõ tiếng Việt của Apple.
3. Bấm **⌃ Space** để chuyển Việt/Anh (đổi được trong Cài đặt). Icon trên thanh menu: `V` / `E`.

Bản build ký ad-hoc: mỗi lần dựng lại, macOS có thể yêu cầu cấp lại quyền Trợ năng
(xoá mục GoViet cũ trong danh sách rồi thêm lại).

## Khi một ứng dụng bị lặp hoặc mất chữ

Trên thanh menu, chọn **Cách gửi phím ở <ứng dụng>** và thử lần lượt các cách, hoặc tăng
**độ trễ giữa các phím** trong Cài đặt.

## Gõ chữ tiếng Anh ở chế độ tiếng Việt

- Từ không thể là tiếng Việt được giữ nguyên: `text`, `class`, `windows`, `coffee`, `error`, `Larry`.
- Gõ đôi phím dấu để bỏ dấu (Telex chuẩn): `pussh` → `push`, `serrver` → `server`.
- Vì vậy chữ đôi thật đứng trước phụ âm hoặc cuối từ cần gõ ba lần: `passsword` → `password`, `passs` → `pass`.
- Đoạn dài tiếng Anh: bấm ⌃ Space để chuyển sang chế độ E.

## Clipboard

- **⌃⌥V** mở menu tại con trỏ chuột: chọn một mục trong lịch sử để dán (phím 1–9 chọn nhanh),
  hoặc **Chuyển mã clipboard**: bỏ dấu, TCVN3 → Unicode, VNI Windows → Unicode, Unicode tổ hợp → dựng sẵn,
  CHỮ HOA, chữ thường, Viết Hoa Đầu Từ.
- Lịch sử (25 mục gần nhất) chỉ nằm trong bộ nhớ, mất khi thoát app. Nội dung do trình quản lý mật khẩu
  đánh dấu là mật khẩu không được lưu. Tắt trong Cài đặt → Chung.

## Gõ tắt

Cài đặt → Gõ tắt: thêm từ viết tắt (chỉ chữ a–z) và cụm đầy đủ. Gõ từ viết tắt rồi dấu cách hoặc dấu câu
(`. , ; : ! ?`) để thay. Giữ kiểu chữ hoa: `vn` → `Việt Nam`, `Vn` → `Việt Nam`, `VN` → `VIỆT NAM`.

**Nhập/xuất:** nút *Xuất ra file…* ghi JSON (`{"vn": "Việt Nam"}`). *Nhập từ file…* nhận JSON đó, hoặc văn bản
mỗi dòng một mục `vn<Tab>Việt Nam`, `vn = Việt Nam`, `vn: Việt Nam` (dòng bắt đầu `#` là ghi chú). Mục trùng viết tắt
được ghi đè bằng mục trong file.

## Soạn code và terminal

Mặc định không gõ tiếng Việt trong ô soạn code và terminal của VS Code, Cursor, Windsurf, Antigravity…
(ô chat, ô tìm kiếm vẫn gõ được) và trong các ứng dụng terminal (Terminal, iTerm2, Warp, Ghostty…).
GoViet phải bật cây Accessibility của các trình soạn thảo này; để VS Code không tự chuyển sang chế độ
trình đọc màn hình, đặt `"editor.accessibilitySupport": "off"` trong cài đặt VS Code.
