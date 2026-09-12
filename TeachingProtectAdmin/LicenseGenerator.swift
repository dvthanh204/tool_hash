import Foundation
import CryptoKit

public class LicenseGenerator {
    
    public static func generateKeyPair() -> (privateKey: Curve25519.Signing.PrivateKey, publicKeyBase64: String) {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()
        return (privateKey, publicKeyBase64)
    }
    
    public static func generateLicense(
        privateKeyBase64: String,
        machineId: String,
        licenseId: String,
        customer: String,
        validDays: Int
    ) throws -> Data {
        guard let privateKeyData = Data(base64Encoded: privateKeyBase64) else {
            throw GeneratorError.invalidKey
        }
        
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
        
        let issueDate = Date()
        let expireDate = Calendar.current.date(byAdding: .day, value: validDays, to: issueDate)!
        
        let license = License(
            product: "TeachingProtect",
            licenseId: licenseId,
            machineId: machineId,
            customer: customer,
            issuedAt: issueDate,
            expiresAt: expireDate,
            features: ["view", "edit", "save"]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let licenseJsonData = try encoder.encode(license)
        let signature = try privateKey.signature(for: licenseJsonData)
        
        let licenseData = LicenseData(license: license, signature: signature)
        
        let finalData = try encoder.encode(licenseData)
        return finalData
    }
    
    enum GeneratorError: Error {
        case invalidKey
    }
}
