import Foundation
import CoreGraphics

/// Gửi phím giả lập. Mọi event đều gắn dấu `magic` để KeyTap nhận ra và bỏ qua.
final class OutputSender {
    static let magic: Int64 = 0x474F_5649   // "GOVI"
    private static let placeholder: UniChar = 0x202F   // narrow no-break space
    private let source = CGEventSource(stateID: .privateState)

    private let kVKDelete: CGKeyCode = 51
    private let kVKLeft: CGKeyCode = 123
    /// Mã phím dùng cho ký tự Unicode giả lập. Không dùng mã 0 (phím A): khi gõ nhanh, phím A thật có thể chưa nhả
    /// lúc ta gửi "à", và Chromium/Electron bỏ qua keyDown trùng mã với một phím đang được coi là đang giữ.
    /// Dùng phím dấu huyền (`), gần như không bao giờ bị giữ khi gõ chữ.
    private let kVKCarrier: CGKeyCode = 50

    /// Gọi đồng bộ trong callback của event tap để giữ đúng thứ tự phím.
    func send(delete: Int, insert: String, strategy: SendStrategy, delayMs: Int, proxy: CGEventTapProxy) {
        let delayUs = UInt32(max(0, delayMs) * 1000)

        switch strategy {
        case .backspace:
            for _ in 0..<delete { key(kVKDelete, flags: [], proxy, delayUs) }

        case .placeholder:
            if delete > 0 {
                type([Self.placeholder], proxy, delayUs)
                for _ in 0..<(delete + 1) { key(kVKDelete, flags: [], proxy, delayUs) }
            }

        case .selectLeft:
            for _ in 0..<delete { key(kVKLeft, flags: .maskShift, proxy, delayUs) }
        }

        // Mỗi ký tự một sự kiện: nhiều ứng dụng Chromium/Electron xử lý chuỗi nhiều ký tự trong một phím không ổn định.
        for unit in insert.utf16 { type([unit], proxy, delayUs) }
    }

    private func key(_ code: CGKeyCode, flags: CGEventFlags, _ proxy: CGEventTapProxy, _ delayUs: UInt32) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: Self.magic)
            e.tapPostEvent(proxy)
        }
        if delayUs > 0 { usleep(delayUs) }
    }

    private func type(_ units: [UniChar], _ proxy: CGEventTapProxy, _ delayUs: UInt32) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: kVKCarrier, keyDown: down) else { continue }
            e.flags = []
            units.withUnsafeBufferPointer { e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress) }
            e.setIntegerValueField(.eventSourceUserData, value: Self.magic)
            e.tapPostEvent(proxy)
        }
        if delayUs > 0 { usleep(delayUs) }
    }
}
