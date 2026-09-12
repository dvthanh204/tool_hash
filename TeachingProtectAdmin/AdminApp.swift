import SwiftUI

@main
struct AdminApp: App {
    var body: some Scene {
        WindowGroup {
            AdminMainView()
        }
    }
}

struct AdminMainView: View {
    @AppStorage("privateKeyBase64") var privateKeyBase64: String = ""
    @AppStorage("publicKeyBase64") var publicKeyBase64: String = ""
    
    @State private var machineIdInput = ""
    @State private var customerName = ""
    @State private var generatedLicensePath = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("TeachingProtect - Admin Panel")
                .font(.largeTitle)
            
            if privateKeyBase64.isEmpty {
                Button("Generate Master Key Pair") {
                    let keys = LicenseGenerator.generateKeyPair()
                    privateKeyBase64 = keys.privateKey.rawRepresentation.base64EncodedString()
                    publicKeyBase64 = keys.publicKeyBase64
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(alignment: .leading) {
                    Text("Master Public Key (Put in TeachingProtect App):")
                        .font(.headline)
                    Text(publicKeyBase64)
                        .textSelection(.enabled)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                Divider()
                
                Form {
                    TextField("Customer Machine ID", text: $machineIdInput)
                    TextField("Customer Name", text: $customerName)
                    
                    Button("Generate License File") {
                        generateLicense()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: 400)
                
                if !generatedLicensePath.isEmpty {
                    Text("Saved to: \n\(generatedLicensePath)")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func generateLicense() {
        do {
            let licenseId = UUID().uuidString.prefix(8)
            let licenseData = try LicenseGenerator.generateLicense(
                privateKeyBase64: privateKeyBase64,
                machineId: machineIdInput.trimmingCharacters(in: .whitespacesAndNewlines),
                licenseId: "TP-\(licenseId)",
                customer: customerName,
                validDays: 365
            )
            
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.data] // or .tpkey
            savePanel.nameFieldStringValue = "license.tpkey"
            
            if savePanel.runModal() == .OK, let url = savePanel.url {
                try licenseData.write(to: url)
                generatedLicensePath = url.path
            }
        } catch {
            print("Error generating license: \(error)")
        }
    }
}
