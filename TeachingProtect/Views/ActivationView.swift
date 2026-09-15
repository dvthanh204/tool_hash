import SwiftUI

struct ActivationView: View {
    @EnvironmentObject var appState: AppState
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var message = ""
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundColor(.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Text("SlideLock Secure")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Trình Học Trực Tuyến Chống Sao Chép")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("MÃ BẢO MẬT THIẾT BỊ (MACHINE ID)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        
                    HStack {
                        Text(MachineID.current)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(MachineID.current, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Copy Machine ID")
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    
                    Text("Gửi mã này cho Admin để nhận Khóa kích hoạt bản quyền.")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                
                Divider().opacity(0.5)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("NHẬP MẬT KHẨU KHÓA BÀI HỌC")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        
                    TextField("VD: L3X2...", text: $licenseKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .padding(16)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }
                
                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, -10)
                }
                
                Button(action: activate) {
                    HStack {
                        Spacer()
                        Image(systemName: "key.fill")
                        Text(isActivating ? "ĐANG XÁC THỰC..." : "MỞ BÀI GIẢNG")
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding()
                    .background(licenseKey.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(licenseKey.isEmpty || isActivating)
                .contentShape(Rectangle())
            }
            .padding(40)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 540)
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
