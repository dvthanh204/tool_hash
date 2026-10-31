import Foundation

public struct SecureStorage {
    public static var cacheDirectory: URL {
        var dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(".SlideLock_Cache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
            
            // Ngan chan Spotlight va Finder lap chi muc hoac tim kiem file trong thu muc nay
            let noIndex = dir.appendingPathComponent(".metadata_never_index")
            try? Data().write(to: noIndex)
            
            // Thiet lap co hidden bang URLResourceValues (macOS-native, khong dung Process/chflags)
            var hiddenRes = URLResourceValues()
            hiddenRes.isHidden = true
            try? dir.setResourceValues(hiddenRes)
        }
        return dir
    }
    
    public static var secureVaultURL: URL {
        return cacheDirectory.appendingPathComponent(".session_vault.bin")
    }
    
    public static func createSessionFolder() -> URL {
        var sessionDir = cacheDirectory.appendingPathComponent(".\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sessionDir.path)
        
        let noIndex = sessionDir.appendingPathComponent(".metadata_never_index")
        try? Data().write(to: noIndex)
        
        // Thiet lap co hidden bang URLResourceValues (macOS-native, khong dung Process/chflags)
        var hiddenRes = URLResourceValues()
        hiddenRes.isHidden = true
        try? sessionDir.setResourceValues(hiddenRes)
        
        return sessionDir
    }
    
    public static func closeAllPresentationsInCache() {
        let script = """
        try
            tell application "Microsoft PowerPoint"
                repeat with p in presentations
                    try
                        set fName to (full name of p) as string
                        if fName contains ".SlideLock_Cache" then
                            close p saving no
                        end if
                    end try
                end repeat
            end tell
        end try
        """
        if let scriptObj = NSAppleScript(source: script) {
            scriptObj.executeAndReturnError(nil)
        }
    }
    
    public static func cleanupAll() {
        closeAllPresentationsInCache()
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(".SlideLock_Cache")
        try? FileManager.default.removeItem(at: dir)
        
        // Don dep ca cac file zip va thu muc tam thoi cu neu con sot lai
        let oldZip = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("baigiang.zip")
        try? FileManager.default.removeItem(at: oldZip)
        let oldTemp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TeachingProtectTemp")
        try? FileManager.default.removeItem(at: oldTemp)
    }
}
