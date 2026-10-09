import Cocoa

/// Vùng đang gõ trong ứng dụng: soạn code, terminal, hay ô nhập thường (chat, tìm kiếm…).
enum InputZone: String {
    case code, terminal, other
}

/// Nhận diện vùng gõ bằng Accessibility API.
/// - Ứng dụng terminal (Terminal, iTerm2, Warp…): cả ứng dụng là terminal.
/// - Trình soạn thảo nhân Electron/VS Code (VS Code, Cursor, Windsurf…): đọc class DOM của ô đang focus.
///   Ô soạn code của Monaco có class "inputarea" hoặc "native-edit-context"; terminal tích hợp (xterm.js)
///   có class "xterm-helper-textarea"; còn lại (ô chat, ô tìm kiếm) là vùng thường.
enum FocusZone {
    static let terminalApps: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "dev.warp.Warp",
        "com.mitchellh.ghostty", "net.kovidgoyal.kitty", "org.alacritty", "io.alacritty",
        "com.github.wez.wezterm", "co.zeit.hyper", "com.raphaelamorim.rio", "dev.commandline.waveterm",
    ]

    static let codeEditors: Set<String> = [
        "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.vscodium", "com.todesktop.230313mzl4w4u92",
        "com.exafunction.windsurf", "com.google.antigravity", "com.google.antigravity-ide", "com.trae.app", "co.posit.positron",
    ]

    /// Các tiến trình đã được bật cây Accessibility (Electron chỉ dựng cây khi được yêu cầu).
    private static var enabledPIDs = Set<pid_t>()

    static func zone(bundleID: String?, pid: pid_t?) -> InputZone {
        guard let id = bundleID else { return .other }
        if terminalApps.contains(id) { return .terminal }
        guard codeEditors.contains(id), let pid else { return .other }

        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.05)   // không bao giờ treo phím quá 50 ms
        if !enabledPIDs.contains(pid) {
            AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            enabledPIDs.insert(pid)
        }
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let el = focused, CFGetTypeID(el) == AXUIElementGetTypeID() else { return .other }
        var classes: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el as! AXUIElement, "AXDOMClassList" as CFString, &classes) == .success,
              let list = classes as? [String] else { return .other }
        if list.contains("xterm-helper-textarea") { return .terminal }
        if list.contains("inputarea") || list.contains("native-edit-context") { return .code }
        return .other
    }
}
