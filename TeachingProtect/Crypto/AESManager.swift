import Foundation
import CryptoKit

public struct AESManager {
    
    public static func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }
    
    public static func decrypt(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return decryptedData
    }
    
    public enum CryptoError: Error {
        case encryptionFailed
        case decryptionFailed
    }
}
