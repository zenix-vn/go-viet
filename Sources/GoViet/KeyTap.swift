import Cocoa
import VietEngine

/// Chặn phím toàn hệ thống, chạy engine, và gửi chữ đã sửa ra ứng dụng.
/// Mọi xử lý diễn ra đồng bộ trong callback (trên luồng chính) để không bao giờ đảo thứ tự phím.
final class KeyTap {
    let engine = TelexEngine()
    private let sender = OutputSender()
    private let settings = AppSettings.shared

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Bundle ID của ứng dụng đang active (do AppDelegate cập nhật).
    var frontBundleID: String?
    var isVietnamese = true { didSet { engine.reset() } }
    var onToggle: (() -> Void)?

    var isRunning: Bool { tap != nil }

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

        guard isVietnamese, !settings.isExcluded(frontBundleID) else { return pass }

        if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            engine.reset()
            return pass
        }
        if keyCode == 51 {            // Backspace: phím vẫn đi qua, engine tự cập nhật
            engine.handleBackspace()
            return pass
        }
        guard let ch = asciiLetter(event) else {
            engine.reset()
            return pass
        }

        engine.options = EngineOptions(modernTone: settings.modernTone, wToU: settings.wToU)
        switch engine.handleLetter(ch) {
        case .passThrough:
            return pass
        case .replace(let del, let ins):
            sender.send(delete: del, insert: ins,
                        strategy: settings.strategy(for: frontBundleID),
                        delayMs: settings.keyDelayMs, proxy: proxy)
            return nil
        }
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
