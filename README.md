# Gõ Việt

Bộ gõ tiếng Việt Telex cho macOS, không gạch chân, không lặp chữ. Thiết kế chi tiết: [docs/DESIGN.md](docs/DESIGN.md).

## Dựng và cài

```sh
swift run VietEngineChecks      # kiểm thử engine
Tools/build_app.sh --install    # dựng và chép vào /Applications
```

Cần Swift toolchain (Command Line Tools là đủ), macOS 13 trở lên.

## Lần đầu chạy

1. Mở **Gõ Việt**, cấp quyền **Trợ năng** trong System Settings (ứng dụng sẽ hướng dẫn).
2. Chuyển nguồn nhập của macOS về **ABC** và tắt bộ gõ tiếng Việt của Apple.
3. Bấm **⌃ Space** để chuyển Việt/Anh (đổi được trong Cài đặt). Icon trên thanh menu: `V` / `E`.

Bản build ký ad-hoc: mỗi lần dựng lại, macOS có thể yêu cầu cấp lại quyền Trợ năng
(xoá mục Gõ Việt cũ trong danh sách rồi thêm lại).

## Khi một ứng dụng bị lặp hoặc mất chữ

Trên thanh menu, chọn **Cách gửi phím ở <ứng dụng>** và thử lần lượt các cách, hoặc tăng
**độ trễ giữa các phím** trong Cài đặt.

## Gõ chữ tiếng Anh ở chế độ tiếng Việt

- Từ không thể là tiếng Việt được giữ nguyên: `text`, `class`, `windows`, `coffee`, `error`, `Larry`.
- Gõ đôi phím dấu để bỏ dấu (Telex chuẩn): `pussh` → `push`, `serrver` → `server`.
- Vì vậy chữ đôi thật đứng trước phụ âm hoặc cuối từ cần gõ ba lần: `passsword` → `password`, `passs` → `pass`.
- Đoạn dài tiếng Anh: bấm ⌃ Space để chuyển sang chế độ E.
