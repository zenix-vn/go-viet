import SwiftUI
import ServiceManagement

/// Dùng ObservableObject thay cho @State: Command Line Tools không có plugin macro của SwiftUI.
final class LaunchAtLogin: ObservableObject {
    @Published var enabled = SMAppService.mainApp.status == .enabled {
        didSet {
            guard enabled != oldValue else { return }
            do {
                if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                enabled = SMAppService.mainApp.status == .enabled
            }
        }
    }
}

/// Ô nhập gõ tắt mới (ObservableObject thay cho @State, xem LaunchAtLogin).
final class MacroDraft: ObservableObject {
    @Published var key = ""
    @Published var value = ""
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var launch = LaunchAtLogin()
    @ObservedObject var draft = MacroDraft()

    var body: some View {
        TabView {
            general.tabItem { Label("Chung", systemImage: "gearshape") }
            macros.tabItem { Label("Gõ tắt", systemImage: "text.badge.plus") }
            apps.tabItem { Label("Ứng dụng", systemImage: "square.grid.2x2") }
        }
        .frame(width: 540, height: 400)
        .padding()
    }

    private var general: some View {
        Form {
            Picker("Phím tắt chuyển Việt/Anh", selection: $settings.hotkey) {
                ForEach(Hotkey.allCases) { Text($0.title).tag($0) }
            }
            Picker("Kiểu đặt dấu", selection: $settings.modernTone) {
                Text("Kiểu cũ (hòa, thúy)").tag(false)
                Text("Kiểu mới (hoà, thuý)").tag(true)
            }
            Toggle("Phím w đứng riêng thành ư", isOn: $settings.wToU)
            Toggle("Không gõ tiếng Việt khi soạn code", isOn: $settings.disableInCode)
            Toggle("Không gõ tiếng Việt trong terminal", isOn: $settings.disableInTerminal)
            Text("Áp dụng cho VS Code, Cursor, Windsurf… (ô chat, ô tìm kiếm vẫn gõ tiếng Việt) và các ứng dụng terminal. Để VS Code không tự bật chế độ trình đọc màn hình, đặt \"editor.accessibilitySupport\": \"off\" trong cài đặt VS Code.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Lưu lịch sử clipboard (⌃⌥V để mở)", isOn: $settings.clipboardHistory)
            Text("Lịch sử chỉ nằm trong bộ nhớ, mất khi thoát app; nội dung từ trình quản lý mật khẩu không được lưu.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Khởi động cùng máy", isOn: $launch.enabled)
            Stepper("Độ trễ giữa các phím gửi ra: \(settings.keyDelayMs) ms", value: $settings.keyDelayMs, in: 0...10)
            Text("Chỉ tăng độ trễ khi một ứng dụng bị lặp hoặc mất chữ dù đã thử đổi cách gửi phím ở tab Ứng dụng.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var macros: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Bật gõ tắt", isOn: $settings.macrosEnabled)
            Text("Gõ từ viết tắt rồi dấu cách hoặc dấu câu để thay bằng cụm đầy đủ. \"vn\" → \"Việt Nam\"; gõ \"VN\" ra \"VIỆT NAM\", \"Vn\" ra \"Việt Nam\".")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Viết tắt", text: $draft.key).frame(width: 110)
                TextField("Cụm đầy đủ", text: $draft.value)
                Button("Thêm", action: addMacro)
                    .disabled(draft.key.trimmingCharacters(in: .whitespaces).isEmpty || draft.value.isEmpty)
            }
            if settings.macros.isEmpty {
                Text("Chưa có gõ tắt nào.").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(settings.macros.keys.sorted(), id: \.self) { k in
                        HStack {
                            Text(k).bold().frame(width: 110, alignment: .leading)
                            Text(settings.macros[k] ?? "").lineLimit(1)
                            Spacer()
                            Button { settings.macros[k] = nil } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
    }

    private func addMacro() {
        // Viết tắt chỉ gồm chữ cái a-z (bộ gõ nhận diện từ theo phím chữ), không dấu cách
        let key = draft.key.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, key.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            draft.key = String(key.filter { $0.isASCII && $0.isLetter })
            return
        }
        settings.macros[key] = draft.value
        draft.key = ""
        draft.value = ""
    }

    private var apps: some View {
        VStack(alignment: .leading) {
            if settings.rules.isEmpty {
                Text("Chưa có ứng dụng nào được cấu hình riêng.\nDùng nút bên dưới hoặc menu trên thanh menu để thêm.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(settings.rules.keys.sorted(), id: \.self) { id in
                        row(id)
                    }
                }
            }
            HStack {
                Button("Thêm ứng dụng…", action: addApp)
                Spacer()
                Text("Trình duyệt và Spotlight đã được cấu hình sẵn.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ id: String) -> some View {
        let rule = settings.rules[id]!
        return HStack {
            VStack(alignment: .leading) {
                Text(rule.name)
                Text(id).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Tắt", isOn: Binding(
                get: { rule.excluded },
                set: { v in settings.updateRule(id, name: rule.name) { $0.excluded = v } }))
            Picker("", selection: Binding(
                get: { rule.strategy },
                set: { v in settings.updateRule(id, name: rule.name) { $0.strategy = v } })) {
                Text("Tự động").tag(SendStrategy?.none)
                ForEach(SendStrategy.allCases) { Text($0.title).tag(SendStrategy?.some($0)) }
            }
            .labelsHidden().frame(width: 190)
            Button { settings.rules[id] = nil } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url),
              let id = bundle.bundleIdentifier else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        // Thêm với cách gửi hiện đang dùng để người dùng chỉnh tiếp
        settings.rules[id] = AppRule(name: name, excluded: false, strategy: settings.strategy(for: id))
    }
}
