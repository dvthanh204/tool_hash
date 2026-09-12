import SwiftUI

@main
struct TeachingProtectApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            if appState.isActivated {
                MainView()
                    .environmentObject(appState)
            } else {
                ActivationView()
                    .environmentObject(appState)
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var isActivated: Bool = false
    
    init() {
        // Here we could observe LicenseManager.shared.isActivated, but combining logic.
        // For simplicity:
        self.isActivated = LicenseManager.shared.isActivated 
        
        // Setting up an observation wouldn't hurt.
        // In reality, might use Combine to bind LicenseManager.isActivated to self.isActivated
    }
}
