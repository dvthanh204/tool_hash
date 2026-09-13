import SwiftUI

struct ActivationView: View {
    @EnvironmentObject var appState: AppState
    @State private var licenseKey = ""
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
                
                Text("Gửi Machine ID này cho Admin để nhận Key kích hoạt.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)
            
            Divider().padding(.vertical)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Nhập Password Key:")
                    .font(.headline)
                
                TextField("Ví dụ: dGVzdA==", text: $licenseKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
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
            .disabled(licenseKey.isEmpty || isActivating)
            .padding(.top)
        }
        .padding(40)
        .frame(width: 500)
    }
    
    private func activate() {
        isActivating = true
        message = ""
        
        let success = LicenseManager.shared.activate(withKey: licenseKey)
        if success {
            message = "Activation Successful!"
            appState.isActivated = true
        } else {
            message = "Activation Failed. Invalid key or machine mismatch."
        }
        isActivating = false
    }
}
