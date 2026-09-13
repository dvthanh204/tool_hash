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
        // Hmac verification against machine Id
        let currentMachine = MachineID.current
        guard let secretData = "12345678901234567890123456789012".data(using: .utf8),
              let messageData = currentMachine.data(using: .utf8) else {
            return false
        }
        
        let symmetricKey = SymmetricKey(data: secretData)
        let hmac = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
        let expectedSignature = Data(hmac).base64EncodedString()
        
        // So sánh 2 chuỗi Base64
        return keyBase64.trimmingCharacters(in: .whitespacesAndNewlines) == expectedSignature
    }
}
