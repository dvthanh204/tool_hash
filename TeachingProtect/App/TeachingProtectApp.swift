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
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
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
        let tempZipURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("baigiang.zip")
        try? FileManager.default.removeItem(at: tempZipURL)
        
        self.isActivated = LicenseManager.shared.isActivated 
    }
}
