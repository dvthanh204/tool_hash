import Foundation
import CryptoKit

public class LicenseManager {
    
    public static let shared = LicenseManager()
    
    @Published public var isActivated: Bool = false
    
    private init() {
        loadLicense()
    }
    
    public func loadLicense() {
        // Hỗ trợ đọc Key lưu tự động từ UserDefaults để các lần sau vào thẳng không cần nhập
        guard let keyBase64 = UserDefaults.standard.string(forKey: "com.teachingprotect.license") else {
            self.isActivated = false
            return
        }
        
        if validate(keyBase64: keyBase64) {
            self.isActivated = true
        } else {
            self.isActivated = false
        }
    }
    
    public func activate(withKey keyBase64: String) -> Bool {
        if validate(keyBase64: keyBase64) {
             UserDefaults.standard.set(keyBase64, forKey: "com.teachingprotect.license")
             self.isActivated = true
             return true
        }
        return false
    }
    
    private func validate(keyBase64: String) -> Bool {
        let input = keyBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentMachine = MachineID.current
        
        guard let secretData = "12345678901234567890123456789012".data(using: .utf8),
              let messageData = currentMachine.data(using: .utf8) else {
            return false
        }
        
        let symmetricKey = SymmetricKey(data: secretData)
        let hmac = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
        let expectedSignature = Data(hmac).base64EncodedString()
        
        if input != expectedSignature {
            return false
        }
        
        // --- KIỂM TRA REVOCATIONS TỪ GÓI BAIGIANG LÕI ---
        let tempZipURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("baigiang.zip")
        if !FileManager.default.fileExists(atPath: tempZipURL.path) {
            let outsideUrl = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("baigiang.khoa")
            let insideUrl = Bundle.main.url(forResource: "baigiang", withExtension: "khoa")
            
            let bundleUrl: URL?
            if FileManager.default.fileExists(atPath: outsideUrl.path) {
                bundleUrl = outsideUrl
            } else {
                bundleUrl = insideUrl
            }
            
            if let bundleUrl = bundleUrl,
               let data = try? Data(contentsOf: bundleUrl), data.count > 12 {
                if let sealedBox = try? AES.GCM.SealedBox(combined: data),
                   let decrypted = try? AES.GCM.open(sealedBox, using: symmetricKey) {
                    try? decrypted.write(to: tempZipURL)
                }
            }
        }
        
        if FileManager.default.fileExists(atPath: tempZipURL.path) {
            let task = Process()
            task.launchPath = "/usr/bin/unzip"
            task.arguments = ["-p", tempZipURL.path, "revocations.json"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            let revData = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if let json = try? JSONSerialization.jsonObject(with: revData) as? [String: Int] {
                if json[currentMachine] != nil {
                    return false // Có mặt trong sổ đen là phế khóa
                }
            }
        }
        
        return true
    }
}
