# GoViet — Bộ gõ tiếng Việt cho macOS

> Tài liệu thiết kế · phiên bản 0.1 · 2026-10-09
> **GoViet** nghĩa là *Gõ Việt*: gõ tiếng Việt. Phát triển bởi **[Zenix Labs](https://zenix.vn/)**.

---

## 1. Mục tiêu

Làm một bộ gõ Telex cho macOS để gõ tiếng Việt **không còn khó chịu** như bộ gõ có sẵn của Apple:

| # | Mục tiêu | Thước đo |
|---|----------|----------|
| G1 | **Không gạch chân** khi đang gõ | Không dùng *marked text* ở bất kỳ ứng dụng nào |
| G2 | **Không lặp chữ / mất chữ** | Bộ test ở mục 9 chạy đạt 100% trên các ứng dụng mục tiêu |
| G3 | Gõ Telex đúng chính tả, đặt dấu đúng | Toàn bộ bảng test của engine đạt |
| G4 | Nhẹ, nhanh | Xử lý mỗi phím < 1 ms, RAM < 30 MB, không chiếm CPU khi rảnh |
| G5 | Dễ bật/tắt | Một phím tắt chuyển V/E, nhớ chế độ theo từng ứng dụng |

**Ngoài phạm vi phiên bản 1:** kiểu gõ VNI/VIQR, bảng mã cũ (TCVN3, VNI-Windows), gõ tắt (macro), đồng bộ cài đặt qua iCloud. Những phần này có thể làm ở các bản sau.

---

## 2. Vì sao bộ gõ có sẵn của macOS gây lỗi

### 2.1 Gạch chân là do *marked text*

Bộ gõ tiếng Việt của Apple được xây dựng trên **InputMethodKit (IMK)**. Khi đang gõ một từ, IMK giữ từ đó ở trạng thái **marked text** (văn bản đang soạn, chưa chốt). Ứng dụng vẽ gạch chân dưới phần này. Từ chỉ được chốt khi gõ dấu cách, dấu câu hoặc khi focus thay đổi.

Cơ chế này vốn được thiết kế cho tiếng Trung và tiếng Nhật, nơi người dùng phải chọn chữ từ danh sách. Tiếng Việt không cần bước chọn chữ, nên gạch chân chỉ gây vướng mắt.

### 2.2 Lặp chữ và mất chữ cũng do *marked text*

Nhiều ứng dụng không xử lý marked text đầy đủ, nhất là ở các ô có **gợi ý tự động** (autocomplete) hoặc khi chính ứng dụng tự sửa nội dung ô nhập:

- **Thanh địa chỉ và ô tìm kiếm trong Chrome, Edge, Safari:** gợi ý tự hoàn thành chèn vào giữa lúc từ đang soạn, nên khi chốt từ sẽ bị lặp hoặc mất ký tự.
- **Ứng dụng Electron (VS Code, Slack, Discord, Messenger, Zalo…):** khi phím tắt hoặc sự kiện bàn phím được xử lý trước bước chốt từ, chữ bị chèn hai lần.
- **Excel, Google Sheets, Google Docs (vẽ bằng canvas):** từ đang soạn bị chốt sai thời điểm khi chuyển ô hoặc khi web app tự vẽ lại.
- **Terminal và ứng dụng Java (JetBrains):** hỗ trợ marked text chưa đầy đủ.

**Kết luận:** muốn hết cả gạch chân lẫn lặp chữ thì phải **bỏ hẳn marked text**, không chỉ ẩn gạch chân đi.

### 2.3 Cách các bộ gõ bên thứ ba đã làm

OpenKey, EVKey và GoTiengViet dùng cách **chặn phím toàn hệ thống** (CGEventTap). Bộ gõ đọc phím người dùng gõ, rồi tự gửi phím **Backspace** để xoá các ký tự cũ và gõ lại chữ đã có dấu. Ứng dụng chỉ nhận các phím bình thường, nên không có marked text và không có gạch chân.

Cách này cũng có những lỗi riêng, nhưng đều sửa được. Mục 6 trình bày chi tiết.

---

## 3. Các phương án kiến trúc

| Phương án | Gạch chân | Lặp chữ | Tương thích | Nhận xét |
|-----------|-----------|---------|-------------|----------|
| A. IMK + marked text (như Apple) | Có | Có | Trung bình | Chính là nguồn gốc vấn đề |
| B. IMK + `insertText:replacementRange:` (thay thế trực tiếp, không marked text) | Không | Ít | **Kém**: Chrome, Terminal, Electron xử lý `replacementRange` không ổn định | Đúng chuẩn Apple nhưng nhiều ứng dụng làm sai |
| **C. CGEventTap + Backspace** (như OpenKey, EVKey) | **Không** | Ít, nếu có xử lý riêng cho từng loại ứng dụng | **Tốt nhất trên thực tế** | Cần quyền Accessibility, không phát hành được trên Mac App Store |

**Chọn phương án C.** Phương án B được giữ lại làm chiến lược dự phòng cho ứng dụng nào làm việc tốt với nó (xem mục 6.3).

Hệ quả khi chọn C:
- Người dùng giữ nguồn nhập của macOS ở **ABC (U.S.)**. GoViet chạy như một ứng dụng nền trên thanh menu, không phải là một Input Source.
- Ứng dụng cần quyền **Accessibility** (để chặn và gửi phím) và có thể cần cả **Input Monitoring**.
- Phát hành bản ký Developer ID kèm notarize, tải trực tiếp, vì sandbox của Mac App Store không cho phép event tap.

---

## 4. Kiến trúc tổng thể

```
┌──────────────────────────────────────────────────────────────┐
│                     GoViet.app (menu bar)                    │
│                                                              │
│  ┌──────────────┐   phím   ┌──────────────┐  ký tự  ┌──────┐ │
│  │  KeyTap      │────────▶│  Engine      │───────▶│Output│ │
│  │ (CGEventTap) │          │ (Telex, thuần│ (diff)  │Sender│ │
│  └──────┬───────┘          │  Swift)      │         └──┬───┘ │
│         │ chuột/focus      └──────────────┘            │     │
│  ┌──────▼───────┐          ┌──────────────┐            │     │
│  │ Context      │─────────▶│ AppProfile   │────────────┘     │
│  │ Monitor      │ app hiện │ (chiến lược  │ chọn cách gửi    │
│  │ (NSWorkspace,│ tại, role│  theo app)   │                  │
│  │  AX API)     │          └──────────────┘                  │
│  └──────────────┘                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐    │
│  │ Settings     │  │ Hotkey       │  │ Permission       │    │
│  │ (SwiftUI)    │  │ (V/E toggle) │  │ Onboarding       │    │
│  └──────────────┘  └──────────────┘  └──────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### 4.1 Các module

| Module | Trách nhiệm | Phụ thuộc |
|--------|-------------|-----------|
| `VietEngine` (Swift Package) | Xử lý Telex thuần, không phụ thuộc macOS: nhận phím, trả về trạng thái từ mới | Không phụ thuộc gì, test 100% bằng unit test |
| `KeyTap` | Tạo CGEventTap, lọc phím, nuốt phím gốc, chuyển phím cho Engine | CoreGraphics |
| `OutputSender` | Gửi Backspace và ký tự Unicode theo chiến lược của AppProfile | CoreGraphics, AX |
| `ContextMonitor` | Theo dõi app đang active, click chuột, đổi focus, ô mật khẩu; reset bộ đệm khi cần | AppKit, Accessibility |
| `AppProfile` | Bảng cấu hình theo bundle ID: chiến lược gửi, độ trễ, loại trừ | — |
| `UI` | Icon V/E trên thanh menu, cửa sổ cài đặt, hướng dẫn cấp quyền | SwiftUI |

### 4.2 Công nghệ

- **Swift 6**, SwiftUI cho giao diện, AppKit cho `NSStatusItem`.
- macOS tối thiểu: **13 Ventura**.
- Chạy dạng `LSUIElement` (không có icon trên Dock).
- Tự khởi động cùng máy bằng `SMAppService.mainApp`.
- Không dùng thư viện bên thứ ba.

---

## 5. Engine Telex

### 5.1 Mô hình trạng thái

Engine giữ **một từ đang gõ** (bộ đệm). Từ này có hai dạng:

- `raw`: chuỗi phím người dùng đã bấm, ví dụ `t r u o w n g f`.
- `composed`: chữ hiển thị, ví dụ `trường`.

Mỗi lần có phím mới, engine **dựng lại toàn bộ `composed` từ `raw`**, thay vì sửa dần từng bước. Cách này có ba lợi ích:
1. Logic đơn giản và dễ test, vì kết quả chỉ phụ thuộc vào `raw`.
2. Dễ khôi phục lại chữ gốc khi từ không hợp lệ (mục 5.5).
3. Gõ dấu ở cuối từ hay giữa từ đều cho kết quả như nhau.

Đầu ra của engine cho mỗi phím:

```swift
enum EngineResult {
    case passThrough              // không xử lý, để phím đi qua bình thường
    case replace(deleteCount: Int, insert: String)  // xoá N ký tự, gõ chuỗi mới
    case commit                   // kết thúc từ (dấu cách, dấu câu…), reset bộ đệm
}
```

`replace` được tính bằng cách **so sánh `composed` cũ và mới**: tìm phần đầu giống nhau, chỉ xoá và gõ lại phần khác.
Ví dụ `truong` → `trương`: phần đầu chung là `tru`, nên xoá 3 ký tự (`ong`) và gõ `ơng`. Gửi ít phím hơn thì nhanh hơn và ít lỗi hơn.

### 5.2 Quy tắc Telex

| Phím | Tác dụng | Ví dụ |
|------|----------|-------|
| `s` `f` `r` `x` `j` | Dấu sắc, huyền, hỏi, ngã, nặng | `as` → á |
| `z` | Xoá dấu thanh | `asz` → a |
| `aa` `ee` `oo` | â ê ô | `aa` → â |
| `aw` `ow` `uw` | ă ơ ư | `ow` → ơ |
| `uow` / `uwo` | ươ | `nguowif` → người |
| `w` (đứng riêng) | ư (có thể tắt trong cài đặt) | `w` → ư |
| `dd` | đ (cho phép gõ `d` thứ hai ở cuối từ: `did` → đi) | `ddi` → đi |
| `[` `]` | ơ ư (tuỳ chọn, mặc định tắt) | |
| **Gõ hai lần phím dấu** | Huỷ dấu, giữ lại chữ | `ass` → as, `aaa` → aa, `ddd` → dd |

Dấu thanh và dấu mũ **được gõ ở bất kỳ vị trí nào trong từ** (gõ tự do). Ví dụ `tieengs`, `tieesng` và `tiengse` đều cho ra `tiếng`.

### 5.3 Đặt dấu thanh

Engine tách vần thành **phụ âm đầu + âm đệm + âm chính + âm cuối**, rồi đặt dấu theo các quy tắc sau, xét từ trên xuống:

1. Nhóm nguyên âm có chữ mang dấu phụ (â ă ê ô ơ ư) thì đặt dấu lên chữ đó. Với `ươ` thì đặt lên `ơ`: *người, trường*.
2. Có âm cuối thì đặt lên nguyên âm cuối cùng của nhóm: *hoàng, toán, chuyện*.
3. Nhóm có 3 nguyên âm thì đặt lên chữ ở giữa: *ngoài, khuỷu*.
4. Nhóm có 2 nguyên âm, không có âm cuối:
   - **Kiểu cũ** (mặc định): đặt lên chữ đầu: *hòa, thúy, mía, của*.
   - **Kiểu mới**: với `oa`, `oe`, `uy` thì đặt lên chữ sau: *hoà, thuý*. Các trường hợp còn lại vẫn đặt lên chữ đầu.
5. `gi` và `qu` được coi là phụ âm đầu: *giá, quý, quốc*.

Mỗi khi có phím mới, dấu thanh có thể **tự dời sang chữ khác**. Ví dụ gõ `hoaf` được `hoà`, gõ thêm `n` thành `hoàn`, dấu nằm trên chữ `a`.

### 5.4 Chuẩn Unicode

- Luôn xuất **Unicode dựng sẵn (NFC)**, ví dụ `ế` là một code point U+1EBF.
- Nhờ vậy mỗi chữ có dấu chỉ tương ứng với **1 ký tự UTF-16**, và **1 Backspace xoá đúng 1 chữ**. Đây là điều kiện bắt buộc để cách gửi Backspace hoạt động chính xác.

### 5.5 Kiểm tra chính tả và tự khôi phục

- Engine có danh sách **phụ âm đầu** và **vần** hợp lệ của tiếng Việt.
- Nếu `raw` không thể tạo thành âm tiết hợp lệ, engine **không thêm dấu** và giữ nguyên các chữ đã gõ. Ví dụ: `text`, `class`, `windows`, `Xcode`.
- Khi kết thúc từ (dấu cách), nếu từ đã bị thêm dấu nhưng không hợp lệ thì **khôi phục về đúng các phím đã gõ**. Tuỳ chọn này mặc định bật.
- Nhờ vậy, người dùng gõ xen tiếng Anh mà không phải chuyển sang chế độ E.

### 5.6 Backspace và kết thúc từ

| Sự kiện | Xử lý |
|---------|-------|
| Backspace | Cho phím đi qua. Engine bỏ chữ cuối của `composed`, rồi **phân tích ngược** `composed` còn lại thành trạng thái mới, để gõ tiếp vẫn thêm dấu được |
| Dấu cách, Enter, Tab, dấu câu | `commit` và reset bộ đệm |
| Phím mũi tên, Home, End, Page Up/Down | Reset (con trỏ đã rời khỏi từ) |
| Có giữ ⌘, ⌃ hoặc ⌥ | Cho đi qua và reset |
| Click chuột, đổi ứng dụng, đổi cửa sổ | Reset |

---

## 6. Gửi ký tự ra ứng dụng (phần quyết định chống lỗi)

### 6.1 Luồng xử lý một phím

```
Người dùng bấm "f" sau "truong"
  │
  ▼
KeyTap callback (trên luồng của event tap)
  ├─ Event do chính GoViet gửi ra? ── có ──▶ cho qua, không xử lý
  ├─ Đang ở chế độ E, app nằm trong danh sách loại trừ, hoặc là ô mật khẩu? ──▶ cho qua
  ├─ Engine.process("f") ──▶ replace(deleteCount: 3, insert: "ờng")
  ├─ Nuốt phím gốc (callback trả về NULL)
  └─ OutputSender gửi: ⌫ ⌫ ⌫ rồi "ờng"
```

### 6.2 Các nguyên tắc chống lặp chữ và mất chữ

| # | Nguyên tắc | Lý do |
|---|-----------|-------|
| O1 | **Xử lý đồng bộ trong callback** của tap. Không đưa sang luồng khác, không dùng `async` | Nếu xử lý bất đồng bộ, phím tiếp theo có thể đến trước khi Backspace được gửi, dẫn đến sai thứ tự và lặp chữ |
| O2 | Gửi bằng **`CGEventTapPostEvent(proxy, …)`** | Event được chèn ngay tại vị trí của tap, giữ đúng thứ tự so với phím gốc |
| O3 | **Đánh dấu event do mình gửi** bằng `kCGEventSourceUserData` (một giá trị magic) | Tap nhận ra event của chính mình và bỏ qua, tránh vòng lặp vô hạn |
| O4 | Dùng `CGEventSource` riêng với `.privateState` | Trạng thái modifier của event gửi đi không bị lẫn với phím người dùng đang giữ (ví dụ Shift) |
| O5 | Gửi ký tự bằng `CGEventKeyboardSetUnicodeString`, **mỗi event tối đa 20 UTF-16 unit**, có cả event key down và key up | Không phụ thuộc layout bàn phím. Một số app (Electron, Java) bỏ qua ký tự nếu thiếu key up |
| O6 | Nuốt phím gốc và **gửi lại toàn bộ** cả khi chỉ cần thêm một chữ | Tránh tình huống phím gốc đi tới app *sau* các Backspace |
| O7 | **Giảm số phím phải gửi** nhờ so sánh phần đầu giống nhau (mục 5.1) | Gửi ít phím hơn thì ít cơ hội xảy ra race hơn |
| O8 | Cho phép **độ trễ nhỏ giữa các Backspace** theo từng app (mặc định 0, có thể đặt 1–5 ms) | Một số app xử lý phím chậm, nhất là web app nặng |
| O9 | Kiểm tra lại tap khi nhận được `tapDisabledByTimeout` hoặc `tapDisabledByUserInput` thì **bật lại ngay** | macOS tự tắt tap nếu callback chạy quá lâu |

### 6.3 Chiến lược gửi theo từng ứng dụng (AppProfile)

Không có cách gửi nào chạy đúng 100% ở mọi ứng dụng, nên GoViet có nhiều chiến lược và chọn theo **bundle ID** của app, kết hợp với **AXRole** của ô đang focus:

| Chiến lược | Cách làm | Dùng cho |
|-----------|----------|----------|
| **Backspace** (mặc định) | Gửi N lần ⌫, sau đó gõ chuỗi mới | Phần lớn ứng dụng |
| **Ký tự đệm** (`placeholder`) | Gõ một ký tự vô hình (U+202F) để thế chỗ phần gợi ý đang bôi đen, rồi gửi ⌫ × (N+1) và gõ chuỗi mới | **Ô có gợi ý tự động**: thanh địa chỉ Chrome, Edge, Safari, Arc, Firefox, Brave, Opera, Vivaldi; ô tìm kiếm Spotlight |
| **Bôi đen rồi gõ đè** (`selectLeft`) | Gửi N lần ⇧← để bôi đen N ký tự, rồi gõ đè | Ứng dụng nào xử lý ⌫ không ổn nhưng xử lý vùng chọn tốt (chọn thủ công trong cài đặt) |
| IMK replacement (dự phòng, chưa làm) | `insertText:replacementRange:` qua một Input Source phụ | Ứng dụng mà mọi cách trên đều lỗi |

**Vì sao ô có gợi ý cần ký tự đệm:** khi gõ `truong`, trình duyệt tự điền thêm, ví dụ thành `truong`**`.edu.vn`** với phần thêm vào được bôi đen. Lúc đó, ⌫ đầu tiên chỉ **xoá phần gợi ý** chứ không xoá chữ `g`, nên số lần xoá bị lệch đi một và chữ bị lặp. Gõ một ký tự đệm trước sẽ thay phần gợi ý đang bôi đen; sau đó ⌫ × (N+1) xoá đúng ký tự đệm và N chữ cần sửa.

> **Đính chính so với bản 0.1 của tài liệu:** bản đầu dự định dùng ⇧← cho các ô này. Cách đó không dùng được: khi đang có vùng gợi ý bôi đen, ⇧← chỉ *thu nhỏ* vùng chọn từ bên phải chứ không bôi đen chữ bên trái. Ký tự đệm là cách đúng.

**Chọn chiến lược:** phiên bản 1 chọn theo **bundle ID** của ứng dụng đang active (danh sách mặc định nằm trong `AppSettings.swift`, người dùng ghi đè được từng app). Chưa dùng Accessibility API để nhận diện loại ô; đây là hướng cải tiến sau nếu cần phân biệt ô nhập trong cùng một ứng dụng.

Người dùng có thể **tự ghi đè chiến lược cho từng app** trong cài đặt. Ứng dụng đi kèm sẵn một danh sách mặc định.

### 6.4 Các tình huống đặc biệt

| Tình huống | Xử lý |
|-----------|-------|
| Ô mật khẩu (Secure Input) | macOS không gửi phím tới tap, nên tự động không gõ dấu. Kiểm tra `IsSecureEventInputEnabled()` để đổi icon |
| Ứng dụng trong danh sách loại trừ (game, máy ảo, Remote Desktop…) | Không xử lý gì |
| Terminal, iTerm2 | Dùng S1, hoạt động tốt vì terminal nhận Backspace như phím thường |
| Bàn phím layout khác (Dvorak…) | Lấy ký tự bằng `UCKeyTranslate` theo layout hiện tại, không dùng keycode cố định |
| Caps Lock hoặc Shift | Engine giữ đúng chữ hoa và chữ thường theo từng ký tự: `DDaau` → `Đâu` |
| Gõ nhanh (> 15 phím/giây) | Xử lý đồng bộ (O1) bảo đảm đúng thứ tự, không bị mất phím |

---

## 7. Giao diện và trải nghiệm

### 7.1 Thanh menu
- Icon **V** (đang gõ tiếng Việt) hoặc **E** (tiếng Anh). Click để đổi.
- Menu gồm: Bật/tắt · Kiểu đặt dấu (cũ/mới) · Loại trừ app hiện tại · Cài đặt… · Thoát.

### 7.2 Phím tắt
- Mặc định **⌃ Space** hoặc **⌥ Z** để chuyển V/E, có thể đổi trong cài đặt.
- **Nhớ chế độ V/E theo từng app**, ví dụ Terminal luôn ở E và Zalo luôn ở V.

### 7.3 Cửa sổ cài đặt (SwiftUI)
- **Chung:** khởi động cùng máy, phím tắt, âm báo khi chuyển chế độ.
- **Gõ:** kiểu đặt dấu, `w` → ư, `[ ]` → ơ ư, tự khôi phục từ không hợp lệ.
- **Ứng dụng:** bảng gồm bundle ID, chế độ mặc định, chiến lược gửi, độ trễ, loại trừ.
- **Nâng cao:** bật nhật ký debug để ghi lại chuỗi phím và chiến lược đã dùng, giúp báo lỗi.

### 7.4 Hướng dẫn cấp quyền lần đầu
1. Giải thích ngắn gọn vì sao cần quyền Accessibility.
2. Nút mở thẳng **System Settings → Privacy & Security → Accessibility**.
3. Tự phát hiện khi quyền đã được cấp (kiểm tra `AXIsProcessTrusted()` định kỳ), không bắt người dùng khởi động lại app.
4. Nhắc người dùng **chuyển nguồn nhập về ABC** và tắt bộ gõ tiếng Việt của Apple để tránh hai bộ gõ chạy chồng lên nhau.

---

## 8. Bảo mật và quyền riêng tư

- GoViet **không ghi lại và không gửi** phím đi đâu. Ứng dụng không có mã kết nối mạng.
- Nhật ký debug mặc định tắt. Khi bật, nhật ký chỉ lưu trên máy và tự xoá sau 24 giờ.
- Bộ đệm chỉ chứa từ đang gõ và bị xoá khi kết thúc từ.
- Mã nguồn công khai để người dùng tự kiểm chứng (nếu bạn muốn).

---

## 9. Kiểm thử

### 9.1 Unit test cho engine (tự động)
Kiểm thử dạng bảng, mỗi dòng gồm `raw` và kết quả mong đợi, khoảng 500 ca trở lên:

```
nguowif   → người        tieengs   → tiếng       hoaf  → hòa / hoà
khuyeenr  → khuyển       quoocs    → quốc        gias  → giá
ddaayf    → đầy          ass       → as          text  → text (khôi phục)
Truowngf  → Trường       DDOONGF   → ĐỒNG        thuys → thúy / thuý
```

### 9.2 Kiểm thử tích hợp trên các ứng dụng mục tiêu (bán tự động)
Một script gửi phím giả lập gõ câu mẫu, sau đó đọc lại nội dung ô bằng AX API để so sánh.

Câu mẫu: *"Người Việt Nam trường tồn, khuyển mã chi tình, quốc gia hưng thịnh."*

| Nhóm | Ứng dụng |
|------|----------|
| Trình duyệt | Chrome (thanh địa chỉ và Google Docs), Safari, Edge, Firefox, Arc |
| Electron | VS Code, Slack, Discord, Messenger, Zalo, Notion |
| Office | Word, Excel (trong ô và thanh công thức), PowerPoint |
| Apple | Notes, Pages, Messages, Spotlight, Finder (đổi tên file) |
| Khác | Terminal, iTerm2, JetBrains IDE, Telegram, Xcode |

Mỗi ứng dụng phải đạt ba yêu cầu: **không gạch chân, không lặp chữ, không mất chữ**, khi gõ ở cả tốc độ bình thường và tốc độ nhanh (20 phím/giây).

### 9.3 Đo hiệu năng
- Thời gian xử lý trong callback: đo bằng `os_signpost`, p99 phải dưới 1 ms.
- Chạy liên tục 8 giờ không có rò rỉ bộ nhớ (kiểm tra bằng Instruments).

---

## 10. Cấu trúc mã nguồn

Máy phát triển chỉ có Command Line Tools (không có Xcode), nên dự án dùng **Swift Package Manager** và một script đóng gói `.app`.

```
TiengViet/
├── Package.swift
├── icon.png                       # bản thiết kế icon
├── docs/DESIGN.md
├── Sources/
│   ├── VietEngine/                # engine Telex thuần, không phụ thuộc AppKit
│   │   ├── TelexEngine.swift      # xử lý phím → EngineOutput
│   │   ├── Syllable.swift         # tách vần, kiểm tra hợp lệ, vị trí dấu thanh
│   │   └── CharTables.swift       # bảng ký tự dựng sẵn
│   ├── VietEngineChecks/          # bộ kiểm thử engine (swift run VietEngineChecks)
│   └── GoViet/                    # ứng dụng menu bar
│       ├── KeyTap.swift           # CGEventTap
│       ├── OutputSender.swift     # gửi ⌫ / ký tự theo chiến lược
│       ├── AppSettings.swift      # cài đặt, hồ sơ ứng dụng
│       ├── AppDelegate.swift      # menu bar, quyền, nhớ chế độ theo app
│       ├── SettingsView.swift / PermissionView.swift
│       └── main.swift
└── Tools/
    ├── build_app.sh               # dựng "GoViet.app" (--install để chép vào /Applications)
    └── make_icon.swift            # cắt icon.png thành bộ .iconset
```

Ghi chú: Command Line Tools thiếu plugin macro của SwiftUI nên mã giao diện không dùng `@State`; dùng `ObservableObject` thay thế.

---

## 11. Lộ trình

**Tiến độ (2026-10-09):** M1 xong (108 ca kiểm thử engine đạt). M2, M3 (trừ Accessibility nhận diện ô), M4 đã có mã và build được; **chưa kiểm thử trên các ứng dụng thật**. Việc tiếp theo là chạy bảng ở mục 9.2 và chỉnh hồ sơ ứng dụng theo kết quả. M5 (ký Developer ID, notarize) chưa làm.

| Giai đoạn | Nội dung | Kết quả |
|-----------|----------|---------|
| **M1 – Engine** | `VietEngine` với Telex, đặt dấu, kiểm tra chính tả, unit test | Toàn bộ test engine đạt |
| **M2 – MVP** | KeyTap, OutputSender S1, icon trên thanh menu, phím tắt V/E, hướng dẫn cấp quyền | Gõ được trong Notes, TextEdit, VS Code |
| **M3 – Chống lỗi** | S2/S3, AppProfile, ContextMonitor, nhận diện ô bằng AX | Đạt bảng 9.2 với trình duyệt và Electron |
| **M4 – Hoàn thiện** | Cửa sổ cài đặt, nhớ chế độ theo app, loại trừ app, tự khởi động | Bản 1.0 dùng hằng ngày |
| **M5 – Phát hành** | Ký Developer ID, notarize, DMG, tự cập nhật (Sparkle, tuỳ chọn) | Có file cài đặt |
| Sau 1.0 | VNI, gõ tắt, S4 (IMK), sửa từ khi đưa con trỏ quay lại giữa từ | — |

---

## 12. Rủi ro và cách giảm thiểu

| Rủi ro | Mức độ | Giảm thiểu |
|--------|--------|------------|
| Bản cập nhật macOS làm thay đổi cách event tap hoạt động | Trung bình | Kiểm thử trên bản beta của macOS. Giữ S4 (IMK) làm phương án dự phòng |
| Một app mới gặp lỗi lặp chữ | Cao (sẽ xảy ra) | Người dùng tự đổi chiến lược cho app đó trong cài đặt. Nhật ký debug giúp tìm nguyên nhân nhanh |
| Người dùng ngại cấp quyền Accessibility | Thấp | Giải thích rõ ràng, mã nguồn công khai, không có mã kết nối mạng |
| Chạy chồng với bộ gõ của Apple hoặc bộ gõ khác | Trung bình | Phát hiện khi nguồn nhập hiện tại không phải ABC hoặc khi OpenKey/EVKey đang chạy, rồi cảnh báo người dùng |

---

## 13. Các điểm cần bạn quyết định

1. **Tên ứng dụng** chính thức.
2. **Kiểu đặt dấu mặc định:** cũ (*hòa*) hay mới (*hoà*)?
3. **Phím tắt chuyển V/E** mặc định.
4. Có **công khai mã nguồn** không?
5. Bạn có **tài khoản Apple Developer** để ký và notarize không? Nếu chưa có, bản build chỉ chạy được trên máy của bạn sau khi tự cho phép trong System Settings.
