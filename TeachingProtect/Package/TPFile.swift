import Foundation
import CryptoKit

public struct TPHeader: Codable {
    public let version: Int
    public let productId: String
    public let licenseId: String
    public let fileCount: Int
    public let encryptedKey: Data // Khóa SymmetricKey (được mã hóa nếu cần, nhưng thường key có thể được dẫn xuất hoặc lưu an toàn)
    
    public init(version: Int, productId: String, licenseId: String, fileCount: Int, encryptedKey: Data) {
        self.version = version
        self.productId = productId
        self.licenseId = licenseId
        self.fileCount = fileCount
        self.encryptedKey = encryptedKey
    }
}

public struct TPFileInfo: Codable {
    public let fileName: String
    public let fileSize: Int
    public let offset: Int
}
