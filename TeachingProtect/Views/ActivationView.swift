import SwiftUI

struct ActivationView: View {
    @EnvironmentObject var appState: AppState
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var message = ""
    @State private var isSuccess = false
    @State private var isCopied = false
    @State private var shieldScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    @State private var isHoveringBtn = false
    @State private var isHoveringCopy = false
    
    var body: some View {
        ZStack {
            // Background với gradient công nghệ tinh tế
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.12),
                    Color(red: 0.08, green: 0.10, blue: 0.18),
                    Color(red: 0.04, green: 0.05, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            // Vòng tròn ánh sáng nền (Glow Effect)
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 450, height: 450)
                .blur(radius: 80)
                .offset(y: -100)
            
            Circle()
                .fill(Color.purple.opacity(0.10))
                .frame(width: 400, height: 400)
                .blur(radius: 70)
                .offset(x: 150, y: 150)
            
            VStack(spacing: 24) {
                // Header Logo & Title với Animation Nhịp Tim (Pulse)
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.blue.opacity(glowOpacity), Color.clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 58, weight: .bold))
                            .foregroundColor(Color(red: 0.35, green: 0.6, blue: 1.0))
                            .shadow(color: Color.blue.opacity(0.6), radius: 18, x: 0, y: 6)
                            .scaleEffect(shieldScale)
                    }
                    
                    Text("SlideLock Secure")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                            .shadow(color: .green, radius: 4)
                        Text("Hệ Thống Bảo Mật Bài Giảng Bản Quyền")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(white: 0.7))
                    }
                }
                .padding(.top, 10)
                
                // Khung Machine ID (Glassmorphic Card)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "laptopcomputer")
                            .foregroundColor(.blue)
                            .font(.system(size: 13))
                        Text("MÃ BẢO MẬT THIẾT BỊ (MACHINE ID)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(white: 0.6))
                    }
                    
                    HStack {
                        Text(MachineID.current)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(MachineID.current, forType: .string)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                isCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeOut) {
                                    isCopied = false
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text(isCopied ? "Đã chép" : "Sao chép")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isCopied ? Color.green.opacity(0.25) : (isHoveringCopy ? Color.blue.opacity(0.3) : Color.white.opacity(0.08)))
                            .foregroundColor(isCopied ? .green : .white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isCopied ? Color.green.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringCopy = $0 }
                    }
                    .padding(14)
                    .background(Color(white: 0.12).opacity(0.7))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    
                    Text("💡 Sao chép mã này gửi cho Giảng viên / Admin để cấp khóa bản quyền.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.blue.opacity(0.9))
                }
                
                // Khung Nhập Key
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.90))
                            .font(.system(size: 13))
                        Text("NHẬP MÃ BẢN QUYỀN (LICENSE KEY)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(white: 0.6))
                    }
                    
                    TextField("VD: 1234-5678-9012...", text: $licenseKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Color(white: 0.12).opacity(0.7))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(licenseKey.isEmpty ? Color.white.opacity(0.12) : Color.blue.opacity(0.6), lineWidth: 1.5)
                        )
                }
                
                // Thông báo kết quả (Animated message)
                if !message.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isSuccess ? .green : .red)
                        Text(message)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(isSuccess ? .green : Color(red: 1.0, green: 0.4, blue: 0.4))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background((isSuccess ? Color.green : Color.red).opacity(0.12))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .scale))
                }
                
                // Nút Kích hoạt với hiệu ứng Gradient & Glow
                Button(action: activate) {
                    HStack(spacing: 10) {
                        Spacer()
                        if isActivating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 15, weight: .bold))
                        }
                        Text(isActivating ? "ĐANG XÁC THỰC BẢN QUYỀN..." : "MỞ KHÓA BÀI HỌC")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(
                        Group {
                            if licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Color.white.opacity(0.1)
                            } else {
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.45, blue: 1.0),
                                        Color(red: 0.45, green: 0.25, blue: 0.95)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                    )
                    .foregroundColor(licenseKey.isEmpty ? Color(white: 0.4) : .white)
                    .cornerRadius(12)
                    .shadow(
                        color: licenseKey.isEmpty ? .clear : Color.blue.opacity(isHoveringBtn ? 0.6 : 0.35),
                        radius: isHoveringBtn ? 16 : 8,
                        x: 0,
                        y: 4
                    )
                    .scaleEffect(isHoveringBtn && !licenseKey.isEmpty ? 1.015 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating)
                .onHover { isHoveringBtn = $0 }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.09, green: 0.11, blue: 0.17).opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
            )
            .frame(width: 520)
        }
        .frame(minWidth: 560, minHeight: 620)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                shieldScale = 1.06
                glowOpacity = 0.8
            }
        }
    }
    
    private func activate() {
        withAnimation {
            isActivating = true
            message = ""
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let success = LicenseManager.shared.activate(withKey: licenseKey)
            withAnimation(.spring()) {
                if success {
                    isSuccess = true
                    message = "Kích hoạt bản quyền thành công! Đang chuyển hướng..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        appState.isActivated = true
                    }
                } else {
                    isSuccess = false
                    message = "Khóa kích hoạt không hợp lệ hoặc máy tính không trùng khớp."
                }
                isActivating = false
            }
        }
    }
}
