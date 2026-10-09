import Foundation

/// Nhật ký gỡ lỗi, mặc định tắt. Bật: defaults write vn.goviet.GoViet debugLog -bool true (rồi mở lại app).
/// File: ~/Library/Logs/GoViet.log. Ghi cả chữ bạn gõ nên chỉ bật khi cần báo lỗi và xoá sau khi dùng.
enum DebugLog {
    static let enabled = UserDefaults.standard.bool(forKey: "debugLog")
    private static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/GoViet.log")
    private static let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    static func write(_ line: @autoclosure () -> String) {
        guard enabled else { return }
        let text = "\(formatter.string(from: Date())) \(line())\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(Data(text.utf8)); try? h.close()
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
