import Foundation
import AppKit

public class PowerPointLauncher {
    
    public static func launch(file URL: URL) {
        // macOS provides NSWorkspace to open files with default apps.
        // Or explicitly open with Microsoft PowerPoint bundle ID.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        if let pptxUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Powerpoint") {
            NSWorkspace.shared.open([URL], withApplicationAt: pptxUrl, configuration: configuration) { (app, error) in
                if let error = error {
                    print("Failed to open PowerPoint: \(error.localizedDescription)")
                }
            }
        } else {
            // Fallback to default application
            NSWorkspace.shared.open(URL)
        }
    }
}
