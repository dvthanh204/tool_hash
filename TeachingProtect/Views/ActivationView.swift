import SwiftUI

struct ActivationView: View {
    @State private var licenseKeyPath = ""
    @State private var isActivating = false
    @State private var message = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Teaching Protect")
                .font(.largeTitle)
                .bold()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Machine ID:")
                    .font(.headline)
                
                HStack {
                    Text(MachineID.current)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    
                    Spacer()
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(MachineID.current, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                Text("Gửi Machine ID này cho Admin để nhận file License.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)
            
            Divider().padding(.vertical)
            
            HStack {
                Text(licenseKeyPath.isEmpty ? "Select License File..." : (licenseKeyPath as NSString).lastPathComponent)
                    .foregroundColor(licenseKeyPath.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                
                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.data] // Or custom extension like .tpkey
                    
                    if panel.runModal() == .OK {
                        licenseKeyPath = panel.url?.path ?? ""
                    }
                }
            }
            
            if !message.isEmpty {
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button("Activate License") {
                activate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(licenseKeyPath.isEmpty || isActivating)
            .padding(.top)
        }
        .padding(40)
        .frame(width: 500)
    }
    
    private func activate() {
        let url = URL(fileURLWithPath: licenseKeyPath)
        isActivating = true
        message = ""
        
        let success = LicenseManager.shared.activate(with: url)
        if success {
            message = "Activation Successful!"
        } else {
            message = "Activation Failed. Invalid or expired license, or machine mismatch."
        }
        isActivating = false
    }
}
