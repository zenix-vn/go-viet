import Cocoa
import Carbon
import VietEngine

/// Chặn phím toàn hệ thống, chạy engine, và gửi chữ đã sửa ra ứng dụng.
/// Mọi xử lý diễn ra đồng bộ trong callback (trên luồng chính) để không bao giờ đảo thứ tự phím.
final class KeyTap {
    let engine = TelexEngine()
    private let sender = OutputSender()
    private let settings = AppSettings.shared

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Bundle ID và PID của ứng dụng đang active (do AppDelegate cập nhật).
    var frontBundleID: String? { didSet { zone = nil } }
    var frontPID: pid_t?
    /// Vùng gõ hiện tại (code / terminal / thường). nil: chưa biết, sẽ hỏi Accessibility ở phím chữ kế tiếp.
    /// Xoá khi focus có thể đã đổi: click chuột, đổi ứng dụng, phím tắt có ⌘/⌃/⌥, Esc, Tab.
    private var zone: InputZone?
    var isVietnamese = true { didSet { engine.reset() } }
    var onToggle: (() -> Void)?
    var onClipboardHotkey: (() -> Void)?

    var isRunning: Bool { tap != nil }

    /// Thời điểm (ns) của phím chữ trước đó, để nhận ra quãng dừng trước khi bấm lại phím dấu.
    private var lastLetterTime: CGEventTimestamp = 0
    /// Quãng dừng tối thiểu được coi là "nhìn rồi mới bấm". Gõ liền tay thường 70–200 ms giữa hai phím.
    private let pauseThreshold: CGEventTimestamp = 250_000_000

    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let me = Unmanaged<KeyTap>.fromOpaque(refcon!).takeUnretainedValue()
            return me.handle(proxy, type, event)
        }
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        tap = t
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    func stop() {
        if let s = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            engine.reset()
            return pass
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            engine.reset()
            zone = nil
            return pass
        case .keyDown:
            break
        default:
            return pass
        }

        if event.getIntegerValueField(.eventSourceUserData) == OutputSender.magic { return pass }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if settings.hotkey.matches(keyCode: keyCode, flags: flags) {
            onToggle?()
            return nil
        }
        // ⌃⌥V: menu clipboard. Mở sau khi callback trả về, không chặn luồng phím.
        if keyCode == 9, flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]) == [.maskControl, .maskAlternate] {
            DispatchQueue.main.async { [weak self] in self?.onClipboardHotkey?() }
            return nil
        }

        guard isVietnamese, !settings.isExcluded(frontBundleID) else { return pass }

        // Ô mật khẩu / chế độ nhập an toàn: không xử lý, không ghi nhật ký
        if IsSecureEventInputEnabled() {
            engine.reset()
            return pass
        }

        if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            engine.reset()
            zone = nil
            return pass
        }
        if keyCode == 53 || keyCode == 48 { zone = nil }   // Esc, Tab: có thể chuyển focus
        if keyCode == 51 {            // Backspace: phím vẫn đi qua, engine tự cập nhật
            engine.handleBackspace()
            return pass
        }
        guard let ch = asciiLetter(event) else {
            if let out = expandMacro(event, proxy) { return out }
            engine.reset()
            return pass
        }

        // Vùng soạn code / terminal đã tắt tiếng Việt: để phím đi qua như chế độ E
        if zone == nil {
            zone = FocusZone.zone(bundleID: frontBundleID, pid: frontPID)
            DebugLog.write("\(frontBundleID ?? "?") vùng gõ: \(zone!.rawValue)")
        }
        if let z = zone, settings.isDisabled(in: z) {
            engine.reset()
            return pass
        }

        engine.options = EngineOptions(modernTone: settings.modernTone, wToU: settings.wToU)
        let before = String(engine.displayed)
        let now = event.timestamp
        let paused = lastLetterTime > 0 && now > lastLetterTime && now - lastLetterTime >= pauseThreshold
        lastLetterTime = now
        let out = engine.handleLetter(ch, afterPause: paused)
        DebugLog.write("\(frontBundleID ?? "?") gõ \(ch): \"\(before)\" → \"\(String(engine.displayed))\" \(out)\(paused ? " (sau quãng dừng)" : "")")
        switch out {
        case .passThrough:
            return pass
        case .replace(let del, let ins):
            sender.send(delete: del, insert: ins,
                        strategy: settings.strategy(for: frontBundleID),
                        delayMs: settings.keyDelayMs, proxy: proxy)
            return nil
        }
    }

    /// Gõ tắt: dấu cách hoặc dấu câu ngay sau một từ có trong bảng gõ tắt → thay từ đó bằng cụm đầy đủ.
    /// Trả về nil nếu không gõ tắt (để xử lý phím như bình thường).
    private func expandMacro(_ event: CGEvent, _ proxy: CGEventTapProxy) -> Unmanaged<CGEvent>?? {
        guard settings.macrosEnabled, !settings.macros.isEmpty, !engine.isEmpty else { return nil }
        var len = 0
        var buf = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &buf)
        guard len == 1, let s = Unicode.Scalar(buf[0]), " .,;:!?".unicodeScalars.contains(s) else { return nil }
        let word = String(engine.displayed)
        // Khớp chữ trên màn hình trước ("vn"), rồi tới phím đã gõ (gõ tắt "as" dù màn hình đã thành "á")
        guard let expansion = Macro.expand(word, table: settings.macros)
                ?? Macro.expand(engine.typedText, table: settings.macros) else { return nil }
        DebugLog.write("gõ tắt: \(word) → \(expansion)")
        sender.send(delete: word.count, insert: expansion + String(Character(s)),
                    strategy: settings.strategy(for: frontBundleID), delayMs: settings.keyDelayMs, proxy: proxy)
        engine.reset()
        return .some(nil)   // nuốt phím gốc: dấu cách đã được gõ lại sau cụm từ
    }

    private func asciiLetter(_ event: CGEvent) -> Character? {
        var len = 0
        var buf = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &buf)
        guard len == 1, let s = Unicode.Scalar(buf[0]), s.isASCII else { return nil }
        let c = Character(s)
        return c.isLetter ? c : nil
    }
}
