import Foundation
import CryptoKit

public struct SignatureVerifier {
    // IMPORTANT: Thay bằng Base64 Public Key sinh ra từ AdminApp
    public static let publicKeyBase64 = "REPLACE_WITH_BASE64_PUBLIC_KEY"
    
    public static func verify(licenseData: LicenseData) -> Bool {
        guard let publicKeyData = Data(base64Encoded: publicKeyBase64) else {
            print("Invalid public key data.")
            return false
        }
        
        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let licenseJsonData = try encoder.encode(licenseData.license)
            
            let isValid = publicKey.isValidSignature(licenseData.signature, for: licenseJsonData)
            return isValid
        } catch {
            print("Verification error: \(error)")
            return false
        }
    }
}
