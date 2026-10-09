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

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var launch = LaunchAtLogin()

    var body: some View {
        TabView {
            general.tabItem { Label("Chung", systemImage: "gearshape") }
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
            Toggle("Khởi động cùng máy", isOn: $launch.enabled)
            Stepper("Độ trễ giữa các phím gửi ra: \(settings.keyDelayMs) ms", value: $settings.keyDelayMs, in: 0...10)
            Text("Chỉ tăng độ trễ khi một ứng dụng bị lặp hoặc mất chữ dù đã thử đổi cách gửi phím ở tab Ứng dụng.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
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
