import AppKit
import SwiftUI
import Carbon.HIToolbox

// MARK: - Data Models

struct AppConfig: Codable, Identifiable, Equatable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    var screenIndex: Int // Which screen to place the app on (0-based)
    var enabled: Bool
    var fullscreen: Bool // Whether to maximize the app when activated

    init(bundleIdentifier: String, name: String, screenIndex: Int = 0, enabled: Bool = true, fullscreen: Bool = true) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.screenIndex = screenIndex
        self.enabled = enabled
        self.fullscreen = fullscreen
    }
}

struct WorkspaceConfig: Codable {
    var apps: [AppConfig]
    var keyboardShortcut: KeyboardShortcutConfig

    static var `default`: WorkspaceConfig {
        WorkspaceConfig(
            apps: [],
            keyboardShortcut: KeyboardShortcutConfig(keyCode: 35, modifiers: [.command, .shift]) // Cmd+Shift+P
        )
    }
}

struct KeyboardShortcutConfig: Codable {
    var keyCode: UInt32
    var modifiers: Set<ModifierKey>

    enum ModifierKey: String, Codable {
        case command, shift, option, control
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var config: WorkspaceConfig {
        didSet { saveConfig() }
    }
    @Published var installedApps: [InstalledApp] = []

    struct InstalledApp: Identifiable {
        var id: String { bundleIdentifier }
        let bundleIdentifier: String
        let name: String
        let icon: NSImage?
    }

    private let configURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let focusModeDir = appSupport.appendingPathComponent("FocusMode")
        try? FileManager.default.createDirectory(at: focusModeDir, withIntermediateDirectories: true)
        configURL = focusModeDir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: configURL),
           let loaded = try? JSONDecoder().decode(WorkspaceConfig.self, from: data) {
            config = loaded
        } else {
            config = .default
        }

        loadInstalledApps()
    }

    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configURL)
        }
    }

    func loadInstalledApps() {
        var apps: [InstalledApp] = []
        let workspace = NSWorkspace.shared

        // Get apps from /Applications and ~/Applications
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in contents where url.pathExtension == "app" {
                if let bundle = Bundle(url: url),
                   let bundleId = bundle.bundleIdentifier {
                    let name = FileManager.default.displayName(atPath: url.path)
                    let icon = workspace.icon(forFile: url.path)
                    icon.size = NSSize(width: 16, height: 16)
                    apps.append(InstalledApp(bundleIdentifier: bundleId, name: name, icon: icon))
                }
            }
        }

        installedApps = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func activateWorkspace() {
        let enabledApps = config.apps.filter { $0.enabled }
        let enabledBundleIds = Set(enabledApps.map { $0.bundleIdentifier })

        // Get all screens
        let screens = NSScreen.screens

        // First, exit fullscreen for all non-configured apps, then hide them
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bundleId = app.bundleIdentifier,
                  !enabledBundleIds.contains(bundleId) else { continue }

            // Exit fullscreen first using Accessibility API
            exitFullscreen(for: app)
        }

        // Give time for fullscreen animations to complete, then hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for app in NSWorkspace.shared.runningApplications {
                guard app.activationPolicy == .regular,
                      let bundleId = app.bundleIdentifier,
                      !enabledBundleIds.contains(bundleId) else { continue }
                app.hide()
            }
        }

        // Open and position configured apps with staggered timing
        for (index, appConfig) in enabledApps.enumerated() {
            let screenIndex = min(appConfig.screenIndex, screens.count - 1)
            let targetScreen = screens[max(0, screenIndex)]
            let shouldFullscreen = appConfig.fullscreen

            // Check if already running
            if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == appConfig.bundleIdentifier }) {
                runningApp.unhide()
                runningApp.activate(options: [.activateIgnoringOtherApps])
                // Stagger positioning to avoid race conditions
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3 + 0.7) {
                    self.positionApp(runningApp, on: targetScreen, appName: appConfig.name, fullscreen: shouldFullscreen)
                }
            } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appConfig.bundleIdentifier) {
                // Open the app if not running
                let openConfig = NSWorkspace.OpenConfiguration()
                openConfig.activates = true

                let appName = appConfig.name
                NSWorkspace.shared.openApplication(at: appURL, configuration: openConfig) { app, error in
                    guard let app = app, error == nil else { return }
                    // Give app more time to launch and create window
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3 + 1.5) {
                        self.positionApp(app, on: targetScreen, appName: appName, fullscreen: shouldFullscreen)
                    }
                }
            }
        }
    }

    private func exitFullscreen(for app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)

        if result == .success, let windows = windowsRef as? [AXUIElement] {
            for window in windows {
                // Check if window is fullscreen
                var fullscreenRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fullscreenRef) == .success,
                   let isFullscreen = fullscreenRef as? Bool, isFullscreen {
                    // Exit fullscreen by setting AXFullScreen to false
                    AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, false as CFTypeRef)
                }
            }
        }

        // Also try AppleScript as fallback for some apps
        if let appName = app.localizedName {
            let script = """
            tell application "System Events"
                tell process "\(appName)"
                    try
                        set value of attribute "AXFullScreen" of window 1 to false
                    end try
                end tell
            end tell
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    private func positionApp(_ app: NSRunningApplication, on screen: NSScreen, appName: String, fullscreen: Bool) {
        // Try Accessibility API first (more reliable for Chromium-based apps)
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)

        if result == .success, let windows = windowsRef as? [AXUIElement], let window = windows.first {
            let visibleFrame = screen.visibleFrame

            // Set position (Accessibility API uses top-left origin)
            var position = CGPoint(x: visibleFrame.origin.x, y: screen.frame.maxY - visibleFrame.maxY)
            let positionValue = AXValueCreate(.cgPoint, &position)!
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)

            // Set size only if fullscreen is enabled
            if fullscreen {
                var size = CGSize(width: visibleFrame.width, height: visibleFrame.height)
                let sizeValue = AXValueCreate(.cgSize, &size)!
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            }

            return
        }

        // Fallback to AppleScript if Accessibility API fails
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let xPos = Int(visibleFrame.origin.x)
        let yPos = Int(screenFrame.maxY - visibleFrame.maxY)
        let width = Int(visibleFrame.width)
        let height = Int(visibleFrame.height)

        let processName = app.localizedName ?? appName

        let sizeCommand = fullscreen ? "set size of w to {\(width), \(height)}" : ""

        let script = """
        tell application "\(processName)"
            activate
        end tell
        delay 0.3
        tell application "System Events"
            tell process "\(processName)"
                set frontmost to true
                delay 0.1
                try
                    repeat with w in windows
                        set position of w to {\(xPos), \(yPos)}
                        \(sizeCommand)
                    end repeat
                end try
            end tell
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var searchText = ""

    var filteredApps: [AppState.InstalledApp] {
        if searchText.isEmpty {
            return appState.installedApps
        }
        return appState.installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("FocusMode")
                    .font(.headline)
                Spacer()
                Text("⌘⇧P to activate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Search
            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 8)

            // App list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredApps) { installedApp in
                        AppRow(
                            installedApp: installedApp,
                            appConfig: binding(for: installedApp),
                            screenCount: NSScreen.screens.count
                        )
                    }
                }
                .padding(.horizontal)
            }

            Divider()

            // Footer
            HStack {
                Text("\(appState.config.apps.filter { $0.enabled }.count) apps in workspace")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding()
        }
        .frame(width: 350, height: 500)
    }

    func binding(for installedApp: AppState.InstalledApp) -> Binding<AppConfig?> {
        Binding(
            get: {
                appState.config.apps.first { $0.bundleIdentifier == installedApp.bundleIdentifier }
            },
            set: { newValue in
                if let newValue = newValue {
                    if let index = appState.config.apps.firstIndex(where: { $0.bundleIdentifier == installedApp.bundleIdentifier }) {
                        appState.config.apps[index] = newValue
                    } else {
                        appState.config.apps.append(newValue)
                    }
                } else {
                    appState.config.apps.removeAll { $0.bundleIdentifier == installedApp.bundleIdentifier }
                }
            }
        )
    }
}

struct AppRow: View {
    let installedApp: AppState.InstalledApp
    @Binding var appConfig: AppConfig?
    let screenCount: Int

    var isEnabled: Bool {
        appConfig?.enabled ?? false
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // Checkbox
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { enabled in
                        if enabled {
                            appConfig = AppConfig(
                                bundleIdentifier: installedApp.bundleIdentifier,
                                name: installedApp.name,
                                screenIndex: 0,
                                enabled: true,
                                fullscreen: true
                            )
                        } else {
                            appConfig?.enabled = false
                        }
                    }
                ))
                .toggleStyle(.checkbox)

                // App icon
                if let icon = installedApp.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }

                // App name
                Text(installedApp.name)
                    .lineLimit(1)

                Spacer()

                // Screen picker (only show if enabled and multiple screens)
                if isEnabled && screenCount > 1 {
                    Picker("", selection: Binding(
                        get: { appConfig?.screenIndex ?? 0 },
                        set: { appConfig?.screenIndex = $0 }
                    )) {
                        ForEach(0..<screenCount, id: \.self) { index in
                            Text("Screen \(index + 1)").tag(index)
                        }
                    }
                    .frame(width: 90)
                }
            }

            // Fullscreen toggle (only show if enabled)
            if isEnabled {
                HStack {
                    Spacer()
                        .frame(width: 24)
                    Toggle("Maximize window", isOn: Binding(
                        get: { appConfig?.fullscreen ?? true },
                        set: { appConfig?.fullscreen = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isEnabled ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var appState: AppState!
    var eventMonitor: Any?
    var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "target", accessibilityDescription: "FocusMode")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 350, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: SettingsView(appState: appState))

        // Register global hotkey (Cmd+Shift+P)
        registerHotKey()

        // Check accessibility permissions
        checkAccessibilityPermissions()
    }

    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if !trusted {
            print("Please grant accessibility permissions in System Preferences > Privacy & Security > Accessibility")
        }
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func registerHotKey() {
        // Register Cmd+Shift+P as global hotkey
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x464D4F44) // "FMOD"
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Install handler
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            // Post notification to activate workspace
            NotificationCenter.default.post(name: .activateWorkspace, object: nil)
            return noErr
        }, 1, &eventType, nil, nil)

        // Register hotkey: Cmd+Shift+P (keycode 35 = P)
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(35, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        // Listen for activation
        NotificationCenter.default.addObserver(forName: .activateWorkspace, object: nil, queue: .main) { [weak self] _ in
            self?.appState.activateWorkspace()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
}

extension Notification.Name {
    static let activateWorkspace = Notification.Name("activateWorkspace")
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Menu bar only, no dock icon
app.run()
