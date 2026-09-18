import Foundation
import CryptoKit

public class LicenseManager {
    
    public static let shared = LicenseManager()
    
    @Published public var isActivated: Bool = false
    
    private init() {
        loadLicense()
    }
    
    private func getPackageId() -> String {
        let outsideUrl = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("baigiang.khoa")
        let insideUrl = Bundle.main.url(forResource: "baigiang", withExtension: "khoa")
        if FileManager.default.fileExists(atPath: outsideUrl.path), let attrs = try? FileManager.default.attributesOfItem(atPath: outsideUrl.path), let size = attrs[.size] as? UInt64 {
            return "\(size)"
        }
        if let insideUrl = insideUrl, let attrs = try? FileManager.default.attributesOfItem(atPath: insideUrl.path), let size = attrs[.size] as? UInt64 {
            return "\(size)"
        }
        // Fallback for custom file selection logic.
        return "default"
    }

    public func loadLicense() {
        let licenseKey = "com.teachingprotect.license.\(getPackageId())"
        guard let keyBase64 = UserDefaults.standard.string(forKey: licenseKey) else {
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
             let licenseKey = "com.teachingprotect.license.\(getPackageId())"
             UserDefaults.standard.set(keyBase64, forKey: licenseKey)
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
        let sigData = Data(hmac)
        
        let first8 = sigData.prefix(8)
        var num: UInt64 = 0
        for byte in first8 {
            num = (num << 8) | UInt64(byte)
        }
        let codeNum = num % 1000000000000
        let codeStr = String(format: "%012llu", codeNum)
        let formattedExpected = "\(codeStr.prefix(4))-\(codeStr.dropFirst(4).prefix(4))-\(codeStr.dropFirst(8).prefix(4))"
        let cleanInput = input.replacingOccurrences(of: "-", with: "")
        
        if cleanInput != codeStr && input != formattedExpected {
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
