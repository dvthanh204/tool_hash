import Foundation
import CryptoKit

public class PackageReader {
    public static func extractAndDecrypt(
        packagePath: URL,
        outputTempPath: URL
    ) throws {
        let packageData = try Data(contentsOf: packagePath)
        
        guard packageData.count > 4 else {
            throw ReaderError.invalidFormat
        }
        
        let headerSize = packageData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        
        let headerEndIndex = 4 + Int(headerSize)
        guard packageData.count >= headerEndIndex else {
            throw ReaderError.invalidFormat
        }
        
        let headerData = packageData.subdata(in: 4..<headerEndIndex)
        let decoder = JSONDecoder()
        let header = try decoder.decode(TPHeader.self, from: headerData)
        
        let symmetricKey = SymmetricKey(data: header.encryptedKey)
        
        let encryptedPayload = packageData.subdata(in: headerEndIndex..<packageData.count)
        
        let decryptedPptxData = try AESManager.decrypt(data: encryptedPayload, key: symmetricKey)
        
        try decryptedPptxData.write(to: outputTempPath)
    }
    
    public enum ReaderError: Error {
        case invalidFormat
    }
}
