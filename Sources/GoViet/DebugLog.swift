import Foundation

/// Nhật ký gỡ lỗi, mặc định tắt. Bật: defaults write vn.goviet.GoViet debugLog -bool true (rồi mở lại app).
/// File ~/Library/Logs/GoViet.log ghi cả chữ bạn gõ, nên: chỉ chủ tài khoản đọc được (0600),
/// tối đa 1 MB, và tự xoá khi cũ hơn 24 giờ. Không ghi gì khi đang ở ô mật khẩu (xem KeyTap).
enum DebugLog {
    static let enabled = UserDefaults.standard.bool(forKey: "debugLog")
    private static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/GoViet.log")
    private static let maxBytes: UInt64 = 1_000_000
    private static let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    /// Gọi khi khởi động: xoá nhật ký cũ hơn 24 giờ, hoặc xoá hẳn nếu nhật ký đang tắt.
    static func cleanUp() {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return }
        let modified = attrs[.modificationDate] as? Date ?? .distantPast
        if !enabled || Date().timeIntervalSince(modified) > 24 * 3600 {
            try? fm.removeItem(at: url)
        }
    }

    static func write(_ line: @autoclosure () -> String) {
        guard enabled else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let h = try? FileHandle(forWritingTo: url) else { return }
        defer { try? h.close() }
        let end = h.seekToEndOfFile()
        if end > maxBytes {             // quá 1 MB: bắt đầu lại
            h.truncateFile(atOffset: 0)
        }
        h.write(Data("\(formatter.string(from: Date())) \(line())\n".utf8))
    }
}
