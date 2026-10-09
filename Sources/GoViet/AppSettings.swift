import Foundation
import SwiftUI

/// Cách gửi chữ đã sửa ra ứng dụng.
enum SendStrategy: String, Codable, CaseIterable, Identifiable {
    case backspace     // ⌫ × N rồi gõ chuỗi mới
    case placeholder   // gõ ký tự đệm (thế chỗ phần gợi ý đang bôi đen), rồi ⌫ × (N+1)
    case selectLeft    // ⇧← × N để bôi đen rồi gõ đè

    var id: String { rawValue }
    var title: String {
        switch self {
        case .backspace: return "Xoá lùi (mặc định)"
        case .placeholder: return "Ký tự đệm (ô có gợi ý)"
        case .selectLeft: return "Bôi đen rồi gõ đè"
        }
    }
}

enum Hotkey: String, Codable, CaseIterable, Identifiable {
    case ctrlSpace, optionZ, ctrlShiftSpace
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ctrlSpace: return "⌃ Space"
        case .optionZ: return "⌥ Z"
        case .ctrlShiftSpace: return "⌃⇧ Space"
        }
    }

    func matches(keyCode: Int, flags: CGEventFlags) -> Bool {
        let f = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
        switch self {
        case .ctrlSpace: return keyCode == 49 && f == .maskControl
        case .optionZ: return keyCode == 6 && f == .maskAlternate
        case .ctrlShiftSpace: return keyCode == 49 && f == [.maskControl, .maskShift]
        }
    }
}

struct AppRule: Codable, Equatable {
    var name: String
    var excluded = false
    var strategy: SendStrategy?   // nil: dùng mặc định theo hồ sơ ứng dụng
}

/// Hồ sơ mặc định: ứng dụng nào cần cách gửi riêng.
enum DefaultProfiles {
    // Thanh địa chỉ / ô tìm kiếm có tự hoàn thành: Backspace đầu tiên chỉ xoá phần gợi ý.
    static let placeholderApps: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser",
        "org.mozilla.firefox", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
        "com.apple.Spotlight",
    ]

    static func strategy(for bundleID: String?) -> SendStrategy {
        guard let id = bundleID else { return .backspace }
        return placeholderApps.contains(id) ? .placeholder : .backspace
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var modernTone: Bool { didSet { d.set(modernTone, forKey: "modernTone") } }
    @Published var wToU: Bool { didSet { d.set(wToU, forKey: "wToU") } }
    @Published var hotkey: Hotkey { didSet { d.set(hotkey.rawValue, forKey: "hotkey") } }
    /// Độ trễ giữa các phím gửi ra, đơn vị ms (0 = không trễ).
    @Published var keyDelayMs: Int { didSet { d.set(keyDelayMs, forKey: "keyDelayMs") } }
    @Published var rules: [String: AppRule] {
        didSet { d.set(try? JSONEncoder().encode(rules), forKey: "rules") }
    }

    private(set) var appModes: [String: Bool]   // true = tiếng Việt

    private init() {
        modernTone = d.bool(forKey: "modernTone")
        wToU = d.object(forKey: "wToU") as? Bool ?? true
        hotkey = Hotkey(rawValue: d.string(forKey: "hotkey") ?? "") ?? .ctrlSpace
        keyDelayMs = d.integer(forKey: "keyDelayMs")
        rules = (d.data(forKey: "rules").flatMap { try? JSONDecoder().decode([String: AppRule].self, from: $0) }) ?? [:]
        appModes = d.dictionary(forKey: "appModes") as? [String: Bool] ?? [:]
    }

    func mode(for bundleID: String?) -> Bool {
        guard let id = bundleID else { return true }
        return appModes[id] ?? true
    }

    func setMode(_ vietnamese: Bool, for bundleID: String?) {
        guard let id = bundleID else { return }
        appModes[id] = vietnamese
        d.set(appModes, forKey: "appModes")
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let id = bundleID else { return false }
        return rules[id]?.excluded ?? false
    }

    func strategy(for bundleID: String?) -> SendStrategy {
        if let id = bundleID, let s = rules[id]?.strategy { return s }
        return DefaultProfiles.strategy(for: bundleID)
    }

    func updateRule(_ id: String, name: String, _ change: (inout AppRule) -> Void) {
        var r = rules[id] ?? AppRule(name: name)
        change(&r)
        if !r.excluded && r.strategy == nil { rules[id] = nil } else { rules[id] = r }
    }
}
