import Cocoa
import SwiftUI
import VietEngine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let settings = AppSettings.shared
    private let keyTap = KeyTap()
    private let clipboard = ClipboardManager()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var permissionWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var permissionTimer: Timer?
    private var hud: NSPanel?
    private var hudToken = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DebugLog.cleanUp()
        setupStatusItem()

        keyTap.frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        keyTap.frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        keyTap.isVietnamese = settings.mode(for: keyTap.frontBundleID)
        keyTap.onToggle = { [weak self] in self?.toggleMode() }
        keyTap.onClipboardHotkey = { [weak self] in self?.clipboard.showPopup() }
        clipboard.notify = { [weak self] in self?.showHUD($0) }
        clipboard.start()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)

        startTapOrAskPermission()
        updateStatusTitle()
        watchPermission()

        // Thanh menu đông (hoặc bị tai thỏ che) có thể làm mất icon: lần đầu chạy thì mở Cài đặt cho dễ thấy.
        if keyTap.isRunning, !UserDefaults.standard.bool(forKey: "didShowWelcome") {
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
            openSettings()
        }
    }

    /// Mở lại ứng dụng (bấm icon trong Finder/Launchpad) khi đang chạy nền: hiện Cài đặt.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if keyTap.isRunning { openSettings() } else { showPermissionWindow() }
        return true
    }

    // MARK: - Quyền và khởi động tap

    private func startTapOrAskPermission() {
        if AXIsProcessTrusted(), keyTap.start() {
            permissionWindow?.close()
            permissionTimer?.invalidate()
            updateStatusTitle()
            return
        }
        if AXIsProcessTrusted(), !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
        showPermissionWindow()
        if permissionTimer == nil {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self else { return }
                if AXIsProcessTrusted(), self.keyTap.start() {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                    self.permissionWindow?.close()
                    self.updateStatusTitle()
                }
            }
        }
    }

    /// Quyền Trợ năng bị thu hồi khi app đang chạy mà tap vẫn còn thì bàn phím có thể bị treo:
    /// kiểm tra định kỳ, mất quyền thì gỡ tap ngay và quay lại màn hình xin quyền.
    private func watchPermission() {
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, self.keyTap.isRunning, !AXIsProcessTrusted() else { return }
            self.keyTap.stop()
            self.updateStatusTitle()
            self.startTapOrAskPermission()
        }
    }

    private func showPermissionWindow() {
        if permissionWindow == nil {
            // Hiện hộp thoại hệ thống một lần để GoViet xuất hiện sẵn trong danh sách Trợ năng
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
            permissionWindow = makeWindow(title: "GoViet", view: PermissionView())
        }
        present(permissionWindow)
    }

    // MARK: - Chế độ Việt/Anh

    @objc private func appActivated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard let id = app?.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return }
        keyTap.frontBundleID = id
        keyTap.frontPID = app?.processIdentifier
        keyTap.isVietnamese = settings.mode(for: id)
        keyTap.engine.reset()
        updateStatusTitle()
    }

    private func toggleMode() {
        keyTap.isVietnamese.toggle()
        settings.setMode(keyTap.isVietnamese, for: keyTap.frontBundleID)
        updateStatusTitle()
        showHUD(keyTap.isVietnamese ? "V  Tiếng Việt" : "E  English")
    }

    /// Thông báo nhỏ ở giữa phía trên màn hình khi chuyển Việt/Anh.
    private func showHUD(_ text: String) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 40, height: 44)
        let panel = hud ?? NSPanel(contentRect: NSRect(origin: .zero, size: size),
                                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        hud = panel
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        let box = NSView(frame: NSRect(origin: .zero, size: size))
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        box.layer?.cornerRadius = 12
        label.frame.origin = NSPoint(x: 20, y: (size.height - label.frame.height) / 2)
        box.addSubview(label)
        panel.contentView = box
        panel.setContentSize(size)
        if let f = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.maxY - size.height - 24))
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        hudToken += 1
        let token = hudToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, token == self.hudToken else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; self.hud?.animator().alphaValue = 0 },
                                                 completionHandler: { if token == self.hudToken { self.hud?.orderOut(nil) } })
        }
    }

    // MARK: - Thanh menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "GoVietStatusItem"
        statusItem.behavior = []   // người dùng không vô tình kéo icon ra khỏi thanh menu
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Icon luôn hiện trên thanh menu: ô đặc chữ V khi gõ tiếng Việt, ô viền chữ E khi ở chế độ Anh.
    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        let running = keyTap.isRunning
        let excluded = settings.isExcluded(keyTap.frontBundleID)
        let vietnamese = running && keyTap.isVietnamese && !excluded
        let letter = !running ? "!" : excluded ? "–" : (keyTap.isVietnamese ? "V" : "E")
        button.image = Self.statusImage(letter: letter, filled: vietnamese)
        button.title = ""
        button.toolTip = !running ? "GoViet: chưa có quyền Trợ năng"
            : excluded ? "GoViet: tắt ở ứng dụng này"
            : (vietnamese ? "GoViet: đang gõ tiếng Việt" : "GoViet: đang gõ tiếng Anh")
    }

    private static func statusImage(letter: String, filled: Bool) -> NSImage {
        let size = NSSize(width: 24, height: 16)
        let font = NSFont.systemFont(ofSize: 12, weight: .heavy)
        let image = NSImage(size: size, flipped: false) { rect in
            let box = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 0.5), xRadius: 4, yRadius: 4)
            let text = letter as NSString
            let ts = text.size(withAttributes: [.font: font])
            let at = NSPoint(x: (rect.width - ts.width) / 2, y: (rect.height - ts.height) / 2)
            if filled {
                NSColor.black.setFill()
                box.fill()
                NSGraphicsContext.current?.compositingOperation = .destinationOut   // khoét chữ
                text.draw(at: at, withAttributes: [.font: font, .foregroundColor: NSColor.black])
            } else {
                NSColor.black.setStroke()
                box.lineWidth = 1.5
                box.stroke()
                text.draw(at: at, withAttributes: [.font: font, .foregroundColor: NSColor.black])
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let appName = frontAppName ?? "ứng dụng này"

        if !keyTap.isRunning {
            menu.addItem(withTitle: "Chưa có quyền Trợ năng…", action: #selector(askPermission), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }
        let vi = menu.addItem(withTitle: "Gõ tiếng Việt", action: #selector(toggleFromMenu), keyEquivalent: "")
        vi.state = keyTap.isVietnamese ? .on : .off
        vi.target = self
        menu.addItem(withTitle: "Phím tắt: \(settings.hotkey.title)", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())

        let old = menu.addItem(withTitle: "Dấu kiểu cũ (hòa, thúy)", action: #selector(setOldTone), keyEquivalent: "")
        old.state = settings.modernTone ? .off : .on
        old.target = self
        let new = menu.addItem(withTitle: "Dấu kiểu mới (hoà, thuý)", action: #selector(setNewTone), keyEquivalent: "")
        new.state = settings.modernTone ? .on : .off
        new.target = self
        menu.addItem(.separator())

        let code = menu.addItem(withTitle: "Không gõ tiếng Việt khi soạn code", action: #selector(toggleCode), keyEquivalent: "")
        code.state = settings.disableInCode ? .on : .off
        code.target = self
        let term = menu.addItem(withTitle: "Không gõ tiếng Việt trong terminal", action: #selector(toggleTerminal), keyEquivalent: "")
        term.state = settings.disableInTerminal ? .on : .off
        term.target = self
        menu.addItem(.separator())

        let clip = NSMenuItem(title: "Clipboard (⌃⌥V)", action: nil, keyEquivalent: "")
        clip.submenu = NSMenu()
        clip.submenu!.addItem(withTitle: "Mở lịch sử clipboard", action: #selector(openClipboard), keyEquivalent: "").target = self
        clip.submenu!.addItem(.separator())
        clipboard.addConversionItems(to: clip.submenu!)
        menu.addItem(clip)
        let macro = menu.addItem(withTitle: "Gõ tắt", action: #selector(toggleMacros), keyEquivalent: "")
        macro.state = settings.macrosEnabled ? .on : .off
        macro.target = self
        menu.addItem(.separator())

        let ex = menu.addItem(withTitle: "Không dùng GoViet ở \(appName)", action: #selector(toggleExclude), keyEquivalent: "")
        ex.state = settings.isExcluded(keyTap.frontBundleID) ? .on : .off
        ex.target = self

        let sub = NSMenu()
        let current = settings.rules[keyTap.frontBundleID ?? ""]?.strategy
        for (title, value) in [("Tự động", SendStrategy?.none)] + SendStrategy.allCases.map({ ($0.title, SendStrategy?.some($0)) }) {
            let item = sub.addItem(withTitle: title, action: #selector(pickStrategy(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value?.rawValue ?? ""
            item.state = current == value ? .on : .off
        }
        let strat = NSMenuItem(title: "Cách gửi phím ở \(appName)", action: nil, keyEquivalent: "")
        strat.submenu = sub
        menu.addItem(strat)
        menu.addItem(.separator())

        menu.addItem(withTitle: "Giới thiệu GoViet", action: #selector(openAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Cài đặt…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Thoát GoViet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    /// Tên ứng dụng mà GoViet đang gõ vào (không phải chính GoViet khi cửa sổ Cài đặt đang mở).
    private var frontAppName: String? {
        guard let id = keyTap.frontBundleID else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName
    }

    @objc private func toggleFromMenu() { toggleMode() }
    @objc private func askPermission() { startTapOrAskPermission() }
    @objc private func openClipboard() {
        // Đợi menu thanh trạng thái đóng hẳn rồi mới mở menu clipboard
        DispatchQueue.main.async { self.clipboard.showPopup() }
    }
    @objc private func toggleMacros() { settings.macrosEnabled.toggle() }
    @objc private func toggleCode() { settings.disableInCode.toggle() }
    @objc private func toggleTerminal() { settings.disableInTerminal.toggle() }
    @objc private func setOldTone() { settings.modernTone = false }
    @objc private func setNewTone() { settings.modernTone = true }

    @objc private func toggleExclude() {
        guard let id = keyTap.frontBundleID else { return }
        settings.updateRule(id, name: frontAppName ?? id) { $0.excluded.toggle() }
        keyTap.engine.reset()
        updateStatusTitle()
    }

    @objc private func pickStrategy(_ item: NSMenuItem) {
        guard let id = keyTap.frontBundleID else { return }
        let name = frontAppName ?? id
        let value = SendStrategy(rawValue: item.representedObject as? String ?? "")
        settings.updateRule(id, name: name) { $0.strategy = value }
    }

    @objc private func openAbout() {
        if aboutWindow == nil {
            aboutWindow = makeWindow(title: "Giới thiệu GoViet", view: AboutView())
        }
        present(aboutWindow)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: "Cài đặt GoViet", view: SettingsView())
        }
        present(settingsWindow)
    }

    // MARK: - Cửa sổ: hiện thì có icon Dock, thu nhỏ (–) hoặc đóng thì chỉ còn icon trên thanh menu

    private func makeWindow<V: View>(title: String, view: V) -> NSWindow {
        let w = NSWindow(contentViewController: NSHostingController(rootView: view))
        w.title = title
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.isReleasedWhenClosed = false
        w.delegate = self
        if let b = w.standardWindowButton(.miniaturizeButton) {
            b.target = self
            b.action = #selector(hideWindow(_:))
        }
        return w
    }

    private func present(_ window: NSWindow?) {
        NSApp.setActivationPolicy(.regular)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func hideWindow(_ sender: NSButton) {
        sender.window?.orderOut(nil)
        updateActivationPolicy()
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { self.updateActivationPolicy() }
    }

    private func updateActivationPolicy() {
        let visible = [settingsWindow, permissionWindow, aboutWindow].contains { $0?.isVisible == true }
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
    }
}
