import Foundation
import CryptoKit

public class LicenseManager {
    
    public static let shared = LicenseManager()
    
    @Published public var isActivated: Bool = false
    
    private init() {
        loadLicense()
    }
    
    private func getDecryptedZipPath() -> String? {
        let vaultURL = SecureStorage.secureVaultURL
        if FileManager.default.fileExists(atPath: vaultURL.path) {
            return vaultURL.path
        }

        let outsideUrl = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("baigiang.khoa")
        let insideUrl = Bundle.main.url(forResource: "baigiang", withExtension: "khoa")
        let bundleUrl: URL? = FileManager.default.fileExists(atPath: outsideUrl.path) ? outsideUrl : insideUrl

        guard let bundleUrl = bundleUrl,
              let data = try? Data(contentsOf: bundleUrl), data.count > 12,
              let secretData = "12345678901234567890123456789012".data(using: .utf8) else {
            return nil
        }

        let symmetricKey = SymmetricKey(data: secretData)
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let decrypted = try? AES.GCM.open(sealedBox, using: symmetricKey) else {
            return nil
        }

        try? decrypted.write(to: vaultURL)
        return vaultURL.path
    }

    private func getPackageId() -> String {
        // Băm nội dung manifest.json để làm mã định danh gói bài giảng, thay vì
        // dùng kích thước file baigiang.khoa: kích thước đó đổi mỗi lần app ghi
        // lại file sau khi đóng bài học (saveAndCleanup), khiến key tra cứu
        // UserDefaults đổi theo và học viên bị yêu cầu nhập lại Key dù đã kích hoạt.
        guard let zipPath = getDecryptedZipPath() else { return "default" }

        let task = Process()
        task.launchPath = "/usr/bin/unzip"
        task.arguments = ["-p", zipPath, "manifest.json"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard !data.isEmpty else { return "default" }
        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        return String(hash.prefix(16))
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
        if let zipPath = getDecryptedZipPath() {
            let task = Process()
            task.launchPath = "/usr/bin/unzip"
            task.arguments = ["-p", zipPath, "revocations.json"]
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
