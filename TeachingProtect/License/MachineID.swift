import Foundation
#if canImport(IOKit)
import IOKit
import CryptoKit

public struct MachineID {
    
    public static var current: String {
        return generateMachineID()
    }
    
    private static func generateMachineID() -> String {
        let macSerial = getMacSerialNumber()
        let hardwareUUID = getHardwareUUID()
        
        let rawID = "\(macSerial)-\(hardwareUUID)"
        return sha256(rawID).prefix(16).enumerated().map { index, char in
            if index > 0 && index % 4 == 0 {
                return "-\(char)"
            }
            return String(char)
        }.joined().uppercased()
    }
    
    private static func getMacSerialNumber() -> String {
        // macOS 12+ requires kIOMainPortDefault instead of kIOMasterPortDefault
        var platformExpert: io_service_t = 0
        if #available(macOS 12.0, *) {
            platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        } else {
            platformExpert = IOServiceGetMatchingService(0, IOServiceMatching("IOPlatformExpertDevice"))
        }
        
        guard platformExpert != 0 else { return "UNKNOWN-SERIAL" }
        defer { IOObjectRelease(platformExpert) }
        
        if let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String {
            return serialNumberAsCFString
        }
        return "UNKNOWN-SERIAL"
    }
    
    private static func getHardwareUUID() -> String {
        var platformExpert: io_service_t = 0
        if #available(macOS 12.0, *) {
            platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        } else {
            platformExpert = IOServiceGetMatchingService(0, IOServiceMatching("IOPlatformExpertDevice"))
        }
        
        guard platformExpert != 0 else { return "UNKNOWN-UUID" }
        defer { IOObjectRelease(platformExpert) }
        
        if let uuidAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String {
            return uuidAsCFString
        }
        return "UNKNOWN-UUID"
    }
    
    private static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
#endif
