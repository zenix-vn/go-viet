import SwiftUI

struct PermissionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                Text("Gõ Việt cần quyền truy cập").font(.title2).bold()
            }
            Text("Để gõ tiếng Việt không gạch chân và không lặp chữ, Gõ Việt cần đọc phím bạn gõ và thay bằng chữ có dấu. macOS gọi đây là quyền **Trợ năng (Accessibility)**.")
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Bấm **Mở Cài đặt** bên dưới.")
                Text("2. Bật công tắc cho **Gõ Việt** trong mục Trợ năng (và Giám sát đầu vào nếu có).")
                Text("3. Quay lại đây: ứng dụng tự nhận quyền, không cần khởi động lại.")
            }
            Text("Gõ Việt không ghi lại phím và không kết nối mạng.").font(.callout).foregroundStyle(.secondary)
            Text("Lưu ý: hãy chuyển nguồn nhập của macOS về **ABC** và tắt bộ gõ tiếng Việt của Apple để hai bộ gõ không chạy chồng nhau.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Mở Cài đặt") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
