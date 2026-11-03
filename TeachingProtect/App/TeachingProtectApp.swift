import SwiftUI
import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    var appState = AppState()

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentView = RootView().environmentObject(appState)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.center()
        window.title = "Khóa Học Từ Xa (SlideLock)"
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        // Tự động gỡ bỏ thuộc tính Quarantine của macOS Gatekeeper trong nền
        DispatchQueue.global(qos: .utility).async {
            let bundlePath = Bundle.main.bundlePath
            let parentDir = Bundle.main.bundleURL.deletingLastPathComponent().path
            
            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            p1.arguments = ["-d", "com.apple.quarantine", bundlePath]
            try? p1.run()
            p1.waitUntilExit()
            
            let p2 = Process()
            p2.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            p2.arguments = ["-cr", bundlePath]
            try? p2.run()
            p2.waitUntilExit()
            
            let p3 = Process()
            p3.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            p3.arguments = ["-d", "com.apple.quarantine", parentDir + "/baigiang.khoa"]
            try? p3.run()
            p3.waitUntilExit()
        }
    }
    
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for file in filenames {
            NotificationCenter.default.post(name: NSNotification.Name("SlideLockOpenFile"), object: file)
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            NotificationCenter.default.post(name: NSNotification.Name("SlideLockOpenFile"), object: url.path)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        let script = """
        tell application "Microsoft PowerPoint"
            try
                close presentations saving no
            end try
        end tell
        """
        NSAppleScript(source: script)?.executeAndReturnError(nil)
        SecureStorage.cleanupAll()
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if appState.isActivated {
            MainView()
        } else {
            ActivationView()
        }
    }
}

class AppState: ObservableObject {
    @Published var isActivated: Bool = false
    
    init() {
        SecureStorage.cleanupAll()
        self.isActivated = LicenseManager.shared.isActivated 
    }
}
