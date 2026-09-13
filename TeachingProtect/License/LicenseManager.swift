import Foundation
import CryptoKit

public class LicenseManager {
    
    public static let shared = LicenseManager()
    
    @Published public var isActivated: Bool = false
    
    private init() {
        loadLicense()
    }
    
    public func loadLicense() {
        // Read from Keychain Manager
        guard let data = KeychainManager.shared.read(service: "com.teachingprotect", account: "license"),
              let keyBase64 = String(data: data, encoding: .utf8) else {
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
             if let data = keyBase64.data(using: .utf8) {
                 KeychainManager.shared.save(data, service: "com.teachingprotect", account: "license")
             }
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
            if let bundleUrl = Bundle.main.url(forResource: "baigiang", withExtension: "khoa"),
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
