import Foundation
import CoreGraphics

/// Gửi phím giả lập. Mọi event đều gắn dấu `magic` để KeyTap nhận ra và bỏ qua.
final class OutputSender {
    static let magic: Int64 = 0x474F_5649   // "GOVI"
    private static let placeholder: UniChar = 0x202F   // narrow no-break space
    private let source = CGEventSource(stateID: .privateState)

    private let kVKDelete: CGKeyCode = 51
    private let kVKLeft: CGKeyCode = 123

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

        let units = Array(insert.utf16)
        var i = 0
        while i < units.count {      // tối đa 20 UTF-16 unit mỗi event
            let end = min(i + 20, units.count)
            type(Array(units[i..<end]), proxy, delayUs)
            i = end
        }
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
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
            e.flags = []
            units.withUnsafeBufferPointer { e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress) }
            e.setIntegerValueField(.eventSourceUserData, value: Self.magic)
            e.tapPostEvent(proxy)
        }
        if delayUs > 0 { usleep(delayUs) }
    }
}
