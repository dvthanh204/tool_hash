import Foundation

public struct License: Codable {
    public let product: String
    public let licenseId: String
    public let machineId: String
    public let customer: String
    public let issuedAt: Date
    public let expiresAt: Date
    public let features: [String]
    
    public init(product: String, licenseId: String, machineId: String, customer: String, issuedAt: Date, expiresAt: Date, features: [String]) {
        self.product = product
        self.licenseId = licenseId
        self.machineId = machineId
        self.customer = customer
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.features = features
    }
}

public struct LicenseData: Codable {
    public let license: License
    public let signature: Data
    
    public init(license: License, signature: Data) {
        self.license = license
        self.signature = signature
    }
}
