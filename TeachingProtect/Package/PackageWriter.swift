import Foundation
import CryptoKit

public class PackageWriter {
    public static func createPackage(
        originalPptxPath: URL,
        outputPath: URL,
        productId: String,
        licenseId: String
    ) throws {
        // Generate a random Symmetric Key for this package
        let symmetricKey = SymmetricKey(size: .bits256)
        
        // In a real scenario, this symmetricKey needs to be encrypted with the Admin's or User's Public Key,
        // OR it's a fixed derived key based on license. Let's just store it as Data for testing.
        let keyData = symmetricKey.withUnsafeBytes { Data($0) }
        
        let header = TPHeader(version: 1, productId: productId, licenseId: licenseId, fileCount: 1, encryptedKey: keyData)
        
        let encoder = JSONEncoder()
        let headerData = try encoder.encode(header)
        
        var headerSize = UInt32(headerData.count).littleEndian
        let headerSizeData = withUnsafeBytes(of: &headerSize) { Data($0) }
        
        let pptxData = try Data(contentsOf: originalPptxPath)
        let encryptedPptxData = try AESManager.encrypt(data: pptxData, key: symmetricKey)
        
        var packageData = Data()
        packageData.append(headerSizeData) // 4 bytes indicating length of JSON header
        packageData.append(headerData)     // The JSON header
        packageData.append(encryptedPptxData) // The AES-GCM Encrypted payload
        
        try packageData.write(to: outputPath)
    }
}
