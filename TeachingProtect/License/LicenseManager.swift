import Foundation

public class LicenseManager {
    
    public static let shared = LicenseManager()
    
    @Published public var currentLicense: License?
    @Published public var isActivated: Bool = false
    
    private init() {
        loadLicense()
    }
    
    public func loadLicense() {
        // Read from Keychain Manager (implemented later)
        guard let data = KeychainManager.shared.read(service: "com.teachingprotect", account: "license"),
              let licenseData = try? JSONDecoder().decode(LicenseData.self, from: data) else {
            self.isActivated = false
            return
        }
        
        if validate(licenseData: licenseData) {
            self.currentLicense = licenseData.license
            self.isActivated = true
        } else {
            self.currentLicense = nil
            self.isActivated = false
        }
    }
    
    public func activate(with licenseFileUrl: URL) -> Bool {
        do {
            let data = try Data(contentsOf: licenseFileUrl)
            
            let decoder = JSONDecoder()
            decoder.dateEncodingStrategy = .iso8601
            let licenseData = try decoder.decode(LicenseData.self, from: data)
            
            if validate(licenseData: licenseData) {
                // Save to Keychain
                KeychainManager.shared.save(data, service: "com.teachingprotect", account: "license")
                self.currentLicense = licenseData.license
                self.isActivated = true
                return true
            }
        } catch {
            print("Activation failed: \(error)")
        }
        return false
    }
    
    private func validate(licenseData: LicenseData) -> Bool {
        // 1. Verify Signature
        guard SignatureVerifier.verify(licenseData: licenseData) else {
            print("Signature is invalid.")
            return false
        }
        
        // 2. Verify Machine ID
        let currentMachine = MachineID.current
        guard licenseData.license.machineId == currentMachine else {
            print("Machine ID mismatch. Bound to \(licenseData.license.machineId), but this is \(currentMachine)")
            return false
        }
        
        // 3. Verify Expiry Date
        guard Date() < licenseData.license.expiresAt else {
            print("License has expired on \(licenseData.license.expiresAt)")
            return false
        }
        
        return true
    }
}
