import SwiftUI

struct AboutView: View {
    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "Phiên bản \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            VStack(spacing: 4) {
                Text("GoViet").font(.system(size: 26, weight: .bold))
                Text("Gõ Việt – bộ gõ tiếng Việt cho macOS").foregroundStyle(.secondary)
                Text(version).font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                feature("keyboard", "Gõ Telex không gạch chân, không lặp chữ, kể cả trên Chrome, VS Code, Office")
                feature("chevron.left.forwardslash.chevron.right", "Tự tắt tiếng Việt khi soạn code và trong terminal")
                feature("text.badge.plus", "Gõ tắt, nhập/xuất danh sách gõ tắt")
                feature("doc.on.clipboard", "Lịch sử clipboard, chuyển mã TCVN3/VNI, bỏ dấu")
                feature("lock.shield", "Không ghi lại phím, không kết nối mạng")
            }
            .padding(.vertical, 6)
            Divider()
            VStack(spacing: 4) {
                Text("Phát triển bởi **Zenix Labs**")
                Link("github.com/zenix-vn/go-viet", destination: URL(string: "https://github.com/zenix-vn/go-viet")!)
                    .font(.callout)
                Text("© 2026 Zenix Labs").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 420)
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(.tint)
            Text(text)
        }
    }
}
