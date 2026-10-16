import Foundation

public struct SecureStorage {
    public static var cacheDirectory: URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(".SlideLock_Cache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
            
            // Ngăn chặn Spotlight và Finder lập chỉ mục hoặc tìm kiếm file trong thư mục này
            let noIndex = dir.appendingPathComponent(".metadata_never_index")
            try? Data().write(to: noIndex)
            
            // Thiết lập cờ hidden trên macOS để Finder hoàn toàn không hiển thị
            let p = Process()
            p.launchPath = "/usr/bin/chflags"
            p.arguments = ["hidden", dir.path]
            try? p.run()
            p.waitUntilExit()
        }
        return dir
    }
    
    public static var secureVaultURL: URL {
        return cacheDirectory.appendingPathComponent(".session_vault.bin")
    }
    
    public static func createSessionFolder() -> URL {
        let sessionDir = cacheDirectory.appendingPathComponent(".\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sessionDir.path)
        
        let noIndex = sessionDir.appendingPathComponent(".metadata_never_index")
        try? Data().write(to: noIndex)
        
        let p = Process()
        p.launchPath = "/usr/bin/chflags"
        p.arguments = ["hidden", sessionDir.path]
        try? p.run()
        p.waitUntilExit()
        
        return sessionDir
    }
    
    public static func cleanupAll() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(".SlideLock_Cache")
        try? FileManager.default.removeItem(at: dir)
        
        // Dọn dẹp cả các file zip và thư mục tạm thời cũ nếu còn sót lại
        let oldZip = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("baigiang.zip")
        try? FileManager.default.removeItem(at: oldZip)
        let oldTemp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TeachingProtectTemp")
        try? FileManager.default.removeItem(at: oldTemp)
    }
}
