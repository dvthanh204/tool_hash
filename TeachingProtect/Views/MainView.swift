import SwiftUI
import Foundation
import CryptoKit

struct AppLogger {
    static func writeLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let docDir = paths.first else { return }
        let logFileURL = docDir.appendingPathComponent("SlideLock_Debug.log")
        
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                if let data = logLine.data(using: .utf8) { fileHandle.write(data) }
                fileHandle.closeFile()
            } else {
                try logLine.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Cannot write log: \(error)")
        }
    }
}

struct MainView: View {
    struct LessonInfo: Hashable {
        let safeName: String
        let displayName: String
    }
    
    @State private var lessons: [LessonInfo] = []
    @State private var selectedLesson: LessonInfo? = nil
    @State private var hoveredLesson: LessonInfo? = nil
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String = "Sẵn sàng học tập bảo mật."
    @State private var customDataURL: URL? = nil
    @State private var hasAccessibilityPermission: Bool = true
    @State private var pulseGlow: Bool = false
    @State private var isHoveringOpenBtn: Bool = false
    @State private var isHoveringActionBtn: Bool = false
    
    private let slideLockHeaderMagic = "SLIDELOCK_ENCRYPTED_FILE_V1"
    private let slideLockPayloadMarker = "---SLIDELOCK_PAYLOAD_BEGIN---\n"
    private let slideLockErrorCode = "0xSL-E994-UNAUTHORIZED_SAVE_AS_DETECTED"
    private let fileLockQueue = DispatchQueue(label: "com.slidelock.filelock.queue")
    
    var body: some View {
        NavigationView {
            // SIDEBAR TRÁI: DANH SÁCH BÀI GIẢNG VÀ CÔNG CỤ
            ZStack {
                Color(red: 0.07, green: 0.09, blue: 0.14).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header Sidebar với Branding và Status Badge
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 38, height: 38)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(red: 0.35, green: 0.65, blue: 1.0))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SlideLock Player")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: .green, radius: pulseGlow ? 4 : 1)
                                Text("Lá chắn: ĐANG BẬT")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.green.opacity(0.9))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Cảnh báo nếu chưa cấp quyền Trợ Năng
                    if !hasAccessibilityPermission {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 16))
                                Text("Cần quyền Trợ Năng (Accessibility)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("SlideLock cần quyền để ngăn chụp/copy/lưu lén bài giảng.")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.8))
                            
                            Button(action: { openAccessibilitySettings() }) {
                                HStack {
                                    Spacer()
                                    Text("Mở Cài Đặt & Cấp Quyền")
                                        .font(.system(size: 11, weight: .bold))
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.18))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.4), lineWidth: 1))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                    }
                    
                    // Nút Mở File PPTX Đã Khóa
                    Button(action: {
                        self.selectAndOpenProtectedFile()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.gearshape.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Mở File PPTX / Đã Khóa")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .opacity(0.6)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.38, blue: 0.95),
                                    Color(red: 0.38, green: 0.22, blue: 0.90)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.blue.opacity(isHoveringOpenBtn ? 0.5 : 0.25), radius: isHoveringOpenBtn ? 10 : 5, x: 0, y: 3)
                        .scaleEffect(isHoveringOpenBtn ? 1.015 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .onHover { isHoveringOpenBtn = $0 }
                    
                    // Tiêu đề danh sách
                    HStack {
                        Text("BÀI HỌC KHÓA")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(white: 0.5))
                        Spacer()
                        Text("\(lessons.count) bài")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                    
                    // Danh sách các bài giảng (Cards)
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(lessons, id: \.self) { lesson in
                                let isSelected = selectedLesson == lesson
                                let isHovered = hoveredLesson == lesson
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedLesson = lesson
                                    }
                                    openLesson(lesson)
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.orange.opacity(0.85), Color.red.opacity(0.85)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 32, height: 32)
                                            Text("P")
                                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                                .foregroundColor(.white)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(lesson.displayName)
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text("Bảo vệ đa lớp SlideLock")
                                                .font(.system(size: 10))
                                                .foregroundColor(Color(white: 0.55))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(isHovered || isSelected ? .blue : Color(white: 0.3))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(
                                                isSelected ? Color.blue.opacity(0.22) :
                                                (isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                isSelected ? Color.blue.opacity(0.6) :
                                                (isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.06)),
                                                lineWidth: 1
                                            )
                                    )
                                    .scaleEffect(isHovered ? 1.01 : 1.0)
                                }
                                .buttonStyle(.plain)
                                .disabled(isProcessing)
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        hoveredLesson = hovering ? lesson : nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                    }
                    
                    if lessons.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "archivebox")
                                .font(.system(size: 36))
                                .foregroundColor(Color(white: 0.3))
                            Text("Chưa nạp bài giảng nào")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(white: 0.6))
                            
                            Button(action: { selectCustomDataFile() }) {
                                Text("Nạp file baigiang.khoa")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                    
                    // Footer Sidebar với Machine ID tóm tắt
                    Divider().background(Color.white.opacity(0.08))
                    HStack {
                        Image(systemName: "cpu")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                        Text(MachineID.current)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .frame(minWidth: 320, maxWidth: 380)
            
            // DETAIL PANEL PHẢI: CHI TIẾT TRÌNH HỌC VÀ LÁ CHẮN BẢO MẬT
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09).edgesIgnoringSafeArea(.all)
                
                // Background Glow
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 500, height: 500)
                    .blur(radius: 90)
                
                if isProcessing {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.6)
                            .padding(.bottom, 10)
                        
                        Text(statusMessage)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Text("Đang thiết lập lá chắn phân giải và giám sát PowerPoint...")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.6))
                    }
                } else if let lesson = selectedLesson ?? lessons.first {
                    VStack(spacing: 28) {
                        // Hero Icon bài học
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.95, green: 0.40, blue: 0.15),
                                                Color(red: 0.85, green: 0.20, blue: 0.30)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color.orange.opacity(0.4), radius: 20, x: 0, y: 8)
                                
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 6) {
                                Text(lesson.displayName)
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("Tệp PowerPoint Được Bảo Vệ Bản Quyền Độc Quyền")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(white: 0.65))
                            }
                        }
                        
                        // Các thẻ tính năng bảo mật (Security Badges)
                        HStack(spacing: 12) {
                            SecurityTag(icon: "lock.shield", text: "AES-256 GCM", color: .blue)
                            SecurityTag(icon: "nosign", text: "Chống Save As", color: .purple)
                            SecurityTag(icon: "doc.on.doc", text: "Chống Copy Slide", color: .indigo)
                            SecurityTag(icon: "shield.lefthalf.filled", text: "Chống Nhân Bản", color: .green)
                        }
                        
                        // Nút Bắt Đầu Học Bài (Action Button)
                        Button(action: { openLesson(lesson) }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("BẮT ĐẦU HỌC BÀI NÀY")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                            }
                            .padding(.horizontal, 36)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.2, green: 0.5, blue: 1.0),
                                        Color(red: 0.4, green: 0.3, blue: 0.95)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: Color.blue.opacity(isHoveringActionBtn ? 0.6 : 0.3), radius: isHoveringActionBtn ? 18 : 8, x: 0, y: 5)
                            .scaleEffect(isHoveringActionBtn ? 1.025 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringActionBtn = $0 }
                        
                        // Khung thông tin bảo mật thời gian thực
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.green)
                                Text("Trạng Thái Hệ Thống")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(white: 0.6))
                                Spacer()
                            }
                            
                            HStack {
                                Text(statusMessage)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(white: 0.85))
                                Spacer()
                            }
                        }
                        .padding(14)
                        .background(Color(white: 0.08).opacity(0.8))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .frame(maxWidth: 460)
                    }
                    .padding(30)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.laptopcomputer")
                            .font(.system(size: 56))
                            .foregroundColor(Color.blue.opacity(0.4))
                        Text(statusMessage)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(white: 0.8))
                        Text("Vui lòng chọn một bài giảng bên trái hoặc mở file tệp PPTX đã khóa.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.5))
                    }
                    .padding(40)
                }
            }
            .frame(minWidth: 480)
        }
        .onAppear {
            self.checkAccessibility()
            self.loadLessons()
            
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
            
            NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                self.checkAccessibility()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SlideLockOpenFile"))) { notif in
            if let path = notif.object as? String {
                let url = URL(fileURLWithPath: path)
                if url.lastPathComponent.lowercased().hasSuffix(".khoa") {
                    self.customDataURL = url
                    self.loadLessons()
                } else {
                    self.openProtectedFile(url: url)
                }
            }
        }
    }
    
        private func checkAccessibility() {
        self.hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    private func openAccessibilitySettings() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func selectAndOpenProtectedFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["pptx", "ppt", "pptm", "ppsx", "khoa"]
        panel.message = "Chọn tệp PPTX bảo mật hoặc tệp baigiang.khoa"
        if panel.runModal() == .OK, let url = panel.url {
            if url.lastPathComponent.lowercased().hasSuffix(".khoa") {
                self.customDataURL = url
                self.loadLessons()
            } else {
                self.openProtectedFile(url: url)
            }
        }
    }
    
    private func openProtectedFile(url: URL) {
        checkAccessibility()
        guard hasAccessibilityPermission else {
            statusMessage = "Vui lòng cấp quyền Trợ Năng cho SlideLock trước khi mở bài học."
            openAccessibilitySettings()
            return
        }
        
        guard LicenseManager.shared.isActivated else {
            statusMessage = "Ứng dụng chưa được kích hoạt bản quyền."
            return
        }
        
        let sessionStartTime = Date()
        isProcessing = true
        let fileName = url.lastPathComponent
        statusMessage = "Đang kiểm tra và mở tệp bảo mật: \(fileName)..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let fileData = try? Data(contentsOf: url), fileData.count > 0 else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Không thể đọc dữ liệu tệp: \(fileName)"
                }
                return
            }
            
            var pptxData: Data? = nil
            let prefixStr = String(data: fileData.prefix(128), encoding: .utf8) ?? ""
            
            if prefixStr.contains(self.slideLockHeaderMagic) {
                guard let markerData = self.slideLockPayloadMarker.data(using: .utf8),
                      let markerRange = fileData.range(of: markerData) else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.statusMessage = "Tệp bị khóa nhưng cấu trúc mã hóa không hợp lệ."
                    }
                    return
                }
                
                let payload = fileData.subdata(in: markerRange.upperBound ..< fileData.count)
                guard payload.count > 28,
                      let secretData = "12345678901234567890123456789012".data(using: .utf8) else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.statusMessage = "Lỗi chuẩn bị chìa khóa giải mã."
                    }
                    return
                }
                
                let symmetricKey = SymmetricKey(data: secretData)
                do {
                    let sealedBox = try AES.GCM.SealedBox(combined: payload)
                    pptxData = try AES.GCM.open(sealedBox, using: symmetricKey)
                } catch {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.statusMessage = "Giải mã thất bại: Tệp có thể đã bị sửa đổi hoặc hỏng."
                    }
                    return
                }
            } else if fileData.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]) {
                pptxData = fileData
            } else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Định dạng tệp không được hỗ trợ. Vui lòng chọn tệp .pptx hoặc tệp đã khóa bởi SlideLock."
                }
                return
            }
            
            guard let finalPptxData = pptxData, finalPptxData.count > 0 else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Dữ liệu bài giảng rỗng."
                }
                return
            }
            
            let sessionFolder = SecureStorage.createSessionFolder()
            let safeName = url.lastPathComponent
            let extractURL = sessionFolder.appendingPathComponent(safeName)
            
            do {
                try finalPptxData.write(to: extractURL)
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Lỗi lưu cache tạm thời: \(error.localizedDescription)"
                }
                return
            }
            
            self.injectDisableSaveAs(pptxPath: extractURL.path)
            let initialFiles = self.snapshotExistingFiles()
            
            DispatchQueue.main.async {
                self.statusMessage = "Đang mở: \(fileName)..."
                
                let script = """
                tell application "Microsoft PowerPoint"
                    activate
                    open (POSIX file "\(extractURL.path)")
                end tell
                """
                if let scriptObj = NSAppleScript(source: script) {
                    var errorInfo: NSDictionary?
                    scriptObj.executeAndReturnError(&errorInfo)
                    if errorInfo != nil {
                        if let pptUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Powerpoint") {
                            let config = NSWorkspace.OpenConfiguration()
                            config.activates = true
                            NSWorkspace.shared.open([extractURL], withApplicationAt: pptUrl, configuration: config, completionHandler: nil)
                        } else {
                            NSWorkspace.shared.open(extractURL)
                        }
                    }
                } else {
                    NSWorkspace.shared.open(extractURL)
                }
                
                self.watchPowerPoint(tempPptxPath: extractURL, sessionDir: sessionFolder, originalName: safeName, sessionStartTime: sessionStartTime, initialFiles: initialFiles, externalSourceURL: url)
            }
        }
    }
    
    enum AppError: Error, LocalizedError {
        case fileNotFound
        case decryptFailed
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "Không tìm thấy file baigiang.khoa ở cùng thư mục ứng dụng. Lỗi có thể do macOS Gatekeeper App Translocation. Hãy chuyển ứng dụng và thư mục dữ liệu ra Desktop, hoặc nhấn Nút 'Chọn file baigiang.khoa' ở cột trái."
            case .decryptFailed: return "Không thể giải mã file dữ liệu. File có thể bị hỏng."
            }
        }
    }
    
    private func selectCustomDataFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        panel.message = "Chọn file baigiang.khoa"
        if panel.runModal() == .OK, let url = panel.url {
            self.customDataURL = url
            self.loadLessons()
        }
    }
    
    private func getDecryptedZipURL() throws -> URL {
        let vaultURL = SecureStorage.secureVaultURL
        if FileManager.default.fileExists(atPath: vaultURL.path) {
            return vaultURL
        }
        
        let outsideUrl = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("baigiang.khoa")
        let insideUrl = Bundle.main.url(forResource: "baigiang", withExtension: "khoa")
        
        let bundleUrl: URL
        if let custom = customDataURL {
            bundleUrl = custom
        } else if FileManager.default.fileExists(atPath: outsideUrl.path) {
            bundleUrl = outsideUrl
        } else if let inside = insideUrl {
            bundleUrl = inside
        } else {
            throw AppError.fileNotFound
        }
        
        guard let data = try? Data(contentsOf: bundleUrl) else { throw AppError.fileNotFound }
        
        let secretData = "12345678901234567890123456789012".data(using: .utf8)!
        let symmetricKey = SymmetricKey(data: secretData)
        guard data.count > 12 else { throw AppError.decryptFailed }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            try decryptedData.write(to: vaultURL)
            return vaultURL
        } catch {
            print("Decrypt failed: \(error)")
            throw AppError.decryptFailed
        }
    }
    
    private func loadLessons() {
        do {
            let zipURL = try getDecryptedZipURL()
            
            let revTask = Process()
            revTask.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            revTask.arguments = ["-p", zipURL.path, "revocations.json"]
            let revPipe = Pipe()
            revTask.standardOutput = revPipe
            try? revTask.run()
            let revData = revPipe.fileHandleForReading.readDataToEndOfFile()
            revTask.waitUntilExit()
            if let revJson = try? JSONSerialization.jsonObject(with: revData) as? [String: Int], revJson[MachineID.current] != nil {
                self.lessons = []
                self.statusMessage = "Máy này đã bị cấm khỏi hệ thống học tập!"
                return
            }
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            task.arguments = ["-p", zipURL.path, "manifest.json"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            try? task.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            var loadedLessons: [LessonInfo] = []
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                let sortedKeys = json.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                for safeName in sortedKeys {
                    if let displayName = json[safeName] {
                        loadedLessons.append(LessonInfo(safeName: safeName, displayName: displayName))
                    }
                }
            } else {
                let task2 = Process()
                task2.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                task2.arguments = ["-Z1", zipURL.path]
                
                let pipe2 = Pipe()
                task2.standardOutput = pipe2
                try? task2.run()
                let data2 = pipe2.fileHandleForReading.readDataToEndOfFile()
                task2.waitUntilExit()
                
                if let output = String(data: data2, encoding: .utf8) {
                    let files = output.components(separatedBy: .newlines).filter { 
                        $0.lowercased().hasSuffix(".pptx") || $0.lowercased().hasSuffix(".ppt") 
                    }.sorted()
                    loadedLessons = files.map { LessonInfo(safeName: $0, displayName: $0) }
                }
            }
            
            self.lessons = loadedLessons
            
            if self.lessons.isEmpty {
                self.statusMessage = "Không có file bài giảng trong gói dữ liệu."
            } else {
                self.statusMessage = "Vui lòng chọn một bài giảng bên danh sách để mở khóa."
            }
        } catch {
            self.lessons = []
            self.statusMessage = "\(error.localizedDescription)"
        }
    }
    
    private func openLesson(_ lesson: LessonInfo) {
        checkAccessibility()
        guard hasAccessibilityPermission else {
            statusMessage = "Vui lòng cấp quyền Trợ Năng cho SlideLock trước khi mở bài học."
            openAccessibilitySettings()
            return
        }
        
        let sessionStartTime = Date()
        isProcessing = true
        statusMessage = "Đang chuẩn bị bài học: \(lesson.displayName)..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let zipURL = try? self.getDecryptedZipURL() else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Lỗi xác thực dữ liệu nguồn."
                }
                return
            }
            
            // Tạo thư mục phiên làm việc ẩn và bảo mật tuyệt đối
            let sessionFolder = SecureStorage.createSessionFolder()
            // Dùng safeName (lesson_0.pptx) thay vì displayName để tránh trùng tên với file thật của user
            let extractURL = sessionFolder.appendingPathComponent(lesson.safeName)
            
            // Trích xuất file bài giảng
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            task.arguments = ["-p", zipURL.path, lesson.safeName]
            let pipe = Pipe()
            task.standardOutput = pipe
            try? task.run()
            let extractedData = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            guard extractedData.count > 0 else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Lỗi giải nén bài giảng."
                }
                return
            }
            
            do {
                try extractedData.write(to: extractURL)
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Lỗi lưu cache tạm thời."
                }
                return
            }
            
            // Chèn bảo vệ CustomUI XML chặn Save As / Export / Print (vẫn cho phép sửa bài, copy nội bộ, tăng cỡ chữ)
            self.injectDisableSaveAs(pptxPath: extractURL.path)
            
            // Chụp snapshot toàn bộ file bài giảng hiện có trên máy trước khi mở bài giảng
            let initialFiles = self.snapshotExistingFiles()
            
            DispatchQueue.main.async {
                self.statusMessage = "Đang mở: \(lesson.displayName)..."
                
                let script = """
                tell application "Microsoft PowerPoint"
                    activate
                    open (POSIX file "\(extractURL.path)")
                end tell
                """
                if let scriptObj = NSAppleScript(source: script) {
                    var errorInfo: NSDictionary?
                    scriptObj.executeAndReturnError(&errorInfo)
                    if errorInfo != nil {
                        if let pptUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Powerpoint") {
                            let config = NSWorkspace.OpenConfiguration()
                            config.activates = true
                            NSWorkspace.shared.open([extractURL], withApplicationAt: pptUrl, configuration: config, completionHandler: nil)
                        } else {
                            NSWorkspace.shared.open(extractURL)
                        }
                    }
                } else {
                    NSWorkspace.shared.open(extractURL)
                }
                
                self.watchPowerPoint(tempPptxPath: extractURL, sessionDir: sessionFolder, originalName: lesson.safeName, sessionStartTime: sessionStartTime, initialFiles: initialFiles)
            }
        }
    }
    
    private func injectDisableSaveAs(pptxPath: String) {
        let tempDir = pptxPath + "_temp_ext"
        
        let unz = Process()
        unz.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unz.arguments = ["-q", "-o", pptxPath, "-d", tempDir]
        try? unz.run()
        unz.waitUntilExit()
        
        // Ghi relationship vào _rels/.rels (root-level)
        let relsPath = tempDir + "/_rels/.rels"
        if var relsData = try? String(contentsOfFile: relsPath, encoding: .utf8) {
            var modified = false
            if !relsData.contains("customUI/customUI.xml") {
                // Dùng đúng namespace 2006 cho customUI 2007
                if let insertIdx = relsData.range(of: "</Relationships>", options: .backwards)?.lowerBound {
                    let relStr = "<Relationship Id=\"rIdCustomUI\" Type=\"http://schemas.microsoft.com/office/2006/relationships/ui/extensibility\" Target=\"customUI/customUI.xml\"/>"
                    relsData = String(relsData[..<insertIdx]) + relStr + String(relsData[insertIdx...])
                    modified = true
                }
            }
            if !relsData.contains("customUI/customUI14.xml") {
                // Dùng đúng namespace 2007 cho customUI14 (Office 2010+/Mac)
                if let insertIdx = relsData.range(of: "</Relationships>", options: .backwards)?.lowerBound {
                    let relStr = "<Relationship Id=\"rIdCustomUI14\" Type=\"http://schemas.microsoft.com/office/2007/relationships/ui/extensibility\" Target=\"customUI/customUI14.xml\"/>"
                    relsData = String(relsData[..<insertIdx]) + relStr + String(relsData[insertIdx...])
                    modified = true
                }
            }
            if modified {
                try? relsData.write(toFile: relsPath, atomically: true, encoding: .utf8)
            }
        } else {
            // Nếu không có file _rels/.rels, tạo mới
            let relsDir = tempDir + "/_rels"
            try? FileManager.default.createDirectory(atPath: relsDir, withIntermediateDirectories: true)
            let defaultRels = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
<Relationship Id="rIdCustomUI" Type="http://schemas.microsoft.com/office/2006/relationships/ui/extensibility" Target="customUI/customUI.xml"/>
<Relationship Id="rIdCustomUI14" Type="http://schemas.microsoft.com/office/2007/relationships/ui/extensibility" Target="customUI/customUI14.xml"/>
</Relationships>
"""
            try? defaultRels.write(toFile: relsPath, atomically: true, encoding: .utf8)
        }
        
        let customUiDir = tempDir + "/customUI"
        try? FileManager.default.createDirectory(atPath: customUiDir, withIntermediateDirectories: true)
        
        // customUI.xml - dùng cho PowerPoint 2007/2008, namespace chính thức 2006/01
        let customXml2007 = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<customUI xmlns="http://schemas.microsoft.com/office/2006/01/customui">
    <commands>
        <command idMso="FileSave" enabled="true"/>
        <command idMso="FileSaveAs" enabled="false"/>
        <command idMso="FileSaveAsMenu" enabled="false"/>
        <command idMso="FileSaveAsMac" enabled="false"/>
        <command idMso="FileSaveAsPdfOrXps" enabled="false"/>
        <command idMso="FileSaveACopy" enabled="false"/>
        <command idMso="FileSaveCopyAs" enabled="false"/>
        <command idMso="FileSaveAsPicture" enabled="false"/>
        <command idMso="PictureSaveAs" enabled="false"/>
        <command idMso="SaveMediaAs" enabled="false"/>
        <command idMso="Export" enabled="false"/>
        <command idMso="FileExport" enabled="false"/>
        <command idMso="FileExportAsPdf" enabled="false"/>
        <command idMso="PublishToPdfOrXps" enabled="false"/>
        <command idMso="CreateVideo" enabled="false"/>
        <command idMso="FileExportToVideo" enabled="false"/>
        <command idMso="PackageForCd" enabled="false"/>
        <command idMso="CreateHandouts" enabled="false"/>
        <command idMso="Share" enabled="false"/>
        <command idMso="ShareDocument" enabled="false"/>
        <command idMso="FileSendAsAttachment" enabled="false"/>
        <command idMso="FileSendAsPdf" enabled="false"/>
        <command idMso="FileSendAsXps" enabled="false"/>
        <command idMso="FilePrint" enabled="false"/>
        <command idMso="FilePrintMac" enabled="false"/>
        <command idMso="FilePrintQuick" enabled="false"/>
        <command idMso="PrintPreviewAndPrint" enabled="false"/>
        <command idMso="ApplicationOptionsDialog" enabled="false"/>
        <command idMso="Duplicate" enabled="false"/>
        <command idMso="FileDuplicate" enabled="false"/>
        <command idMso="FileMove" enabled="false"/>
        <command idMso="Copy" enabled="false"/>
        <command idMso="Cut" enabled="false"/>
        <command idMso="Paste" enabled="false"/>
        <command idMso="PasteSpecial" enabled="false"/>
        <command idMso="ClipboardCopy" enabled="false"/>
        <command idMso="SlideCopy" enabled="false"/>
        <command idMso="SlidePaste" enabled="false"/>
        <command idMso="SlideDuplicate" enabled="false"/>
        <command idMso="SlideCut" enabled="false"/>
        <command idMso="SlideReuse" enabled="false"/>
        <command idMso="SlidesReuse" enabled="false"/>
        <command idMso="ReuseSlides" enabled="false"/>
        <command idMso="SlideMasterDuplicate" enabled="false"/>
        <command idMso="SlideMasterCopy" enabled="false"/>
        <command idMso="SlideLayoutDuplicate" enabled="false"/>
        <command idMso="SlideLayoutCopy" enabled="false"/>
        <command idMso="CopyFormat" enabled="false"/>
        <command idMso="ObjectDuplicate" enabled="false"/>
        <command idMso="SelectionDuplicate" enabled="false"/>
    </commands>
    <ribbon>
        <officeMenu>
            <button idMso="FileSaveAs" visible="false"/>
            <button idMso="FileSaveAsMenu" visible="false"/>
            <button idMso="FilePrint" visible="false"/>
            <button idMso="FilePrintMenu" visible="false"/>
            <menu idMso="FileSendMenu" visible="false"/>
            <button idMso="FilePublishToPdfOrXps" visible="false"/>
        </officeMenu>
        <tabs>
            <tab idMso="TabHome">
                <group idMso="GroupClipboard" visible="false"/>
            </tab>
        </tabs>
    </ribbon>
</customUI>
"""
        try? customXml2007.write(toFile: customUiDir + "/customUI.xml", atomically: true, encoding: .utf8)
        
        // customUI14.xml - dùng cho Office 2010+ và PowerPoint for Mac hiện đại, namespace 2009/07
        let customXml2010 = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<customUI xmlns="http://schemas.microsoft.com/office/2009/07/customui">
    <commands>
        <command idMso="FileSave" enabled="true"/>
        <command idMso="FileSaveAs" enabled="false"/>
        <command idMso="FileSaveAsMenu" enabled="false"/>
        <command idMso="FileSaveAsMac" enabled="false"/>
        <command idMso="FileSaveAsPdfOrXps" enabled="false"/>
        <command idMso="FileSaveACopy" enabled="false"/>
        <command idMso="FileSaveCopyAs" enabled="false"/>
        <command idMso="FileSaveAsPicture" enabled="false"/>
        <command idMso="PictureSaveAs" enabled="false"/>
        <command idMso="SaveMediaAs" enabled="false"/>
        <command idMso="Export" enabled="false"/>
        <command idMso="FileExport" enabled="false"/>
        <command idMso="FileExportAsPdf" enabled="false"/>
        <command idMso="PublishToPdfOrXps" enabled="false"/>
        <command idMso="CreateVideo" enabled="false"/>
        <command idMso="FileExportToVideo" enabled="false"/>
        <command idMso="PackageForCd" enabled="false"/>
        <command idMso="CreateHandouts" enabled="false"/>
        <command idMso="Share" enabled="false"/>
        <command idMso="ShareDocument" enabled="false"/>
        <command idMso="FileSendAsAttachment" enabled="false"/>
        <command idMso="FileSendAsPdf" enabled="false"/>
        <command idMso="FileSendAsXps" enabled="false"/>
        <command idMso="FilePrint" enabled="false"/>
        <command idMso="FilePrintMac" enabled="false"/>
        <command idMso="FilePrintQuick" enabled="false"/>
        <command idMso="PrintPreviewAndPrint" enabled="false"/>
        <command idMso="ApplicationOptionsDialog" enabled="false"/>
        <command idMso="Duplicate" enabled="false"/>
        <command idMso="FileDuplicate" enabled="false"/>
        <command idMso="FileMove" enabled="false"/>
        <command idMso="Copy" enabled="false"/>
        <command idMso="Cut" enabled="false"/>
        <command idMso="Paste" enabled="false"/>
        <command idMso="PasteSpecial" enabled="false"/>
        <command idMso="ClipboardCopy" enabled="false"/>
        <command idMso="SlideCopy" enabled="false"/>
        <command idMso="SlidePaste" enabled="false"/>
        <command idMso="SlideDuplicate" enabled="false"/>
        <command idMso="SlideCut" enabled="false"/>
        <command idMso="SlideReuse" enabled="false"/>
        <command idMso="SlidesReuse" enabled="false"/>
        <command idMso="ReuseSlides" enabled="false"/>
        <command idMso="SlideMasterDuplicate" enabled="false"/>
        <command idMso="SlideMasterCopy" enabled="false"/>
        <command idMso="SlideLayoutDuplicate" enabled="false"/>
        <command idMso="SlideLayoutCopy" enabled="false"/>
        <command idMso="CopyFormat" enabled="false"/>
        <command idMso="ObjectDuplicate" enabled="false"/>
        <command idMso="SelectionDuplicate" enabled="false"/>
    </commands>
    <ribbon>
        <backstage>
            <tab idMso="TabSave" visible="false"/>
            <tab idMso="TabPrint" visible="false"/>
            <tab idMso="TabExport" visible="false"/>
            <tab idMso="TabShare" visible="false"/>
            <tab idMso="TabPublish" visible="false"/>
        </backstage>
        <tabs>
            <tab idMso="TabHome">
                <group idMso="GroupClipboard" visible="false"/>
            </tab>
        </tabs>
    </ribbon>
</customUI>
"""
        try? customXml2010.write(toFile: customUiDir + "/customUI14.xml", atomically: true, encoding: .utf8)
        
        // Xoá font nhúng để tránh lưu lại được
        try? FileManager.default.removeItem(atPath: tempDir + "/ppt/fonts")
        let pRelsPath = tempDir + "/ppt/_rels/presentation.xml.rels"
        if let pRelsData = try? String(contentsOfFile: pRelsPath, encoding: .utf8) {
            let strippedPRels = pRelsData.replacingOccurrences(of: "<Relationship[^>]*relationships/font[^>]*/>", with: "", options: .regularExpression)
            try? strippedPRels.write(toFile: pRelsPath, atomically: true, encoding: .utf8)
        }
        let pXmlPath = tempDir + "/ppt/presentation.xml"
        if let pXmlData = try? String(contentsOfFile: pXmlPath, encoding: .utf8) {
            var strippedPXml = pXmlData.replacingOccurrences(of: "(?is)<p:embeddedFontLst>.*?</p:embeddedFontLst>", with: "", options: .regularExpression)
            strippedPXml = strippedPXml.replacingOccurrences(of: "(?is)<p:embeddedFontLst[^>]*/>", with: "", options: .regularExpression)
            strippedPXml = strippedPXml.replacingOccurrences(of: "(?is)<p:embedTrueTypeFonts\\b[^>]*>.*?</p:embedTrueTypeFonts>", with: "<p:embedTrueTypeFonts val=\"0\"/>", options: .regularExpression)
            strippedPXml = strippedPXml.replacingOccurrences(of: "(?is)<p:embedTrueTypeFonts\\b[^>]*/>", with: "<p:embedTrueTypeFonts val=\"0\"/>", options: .regularExpression)
            strippedPXml = strippedPXml.replacingOccurrences(of: "(?is)<p:saveSubsetFonts\\b[^>]*>.*?</p:saveSubsetFonts>", with: "", options: .regularExpression)
            strippedPXml = strippedPXml.replacingOccurrences(of: "(?is)<p:saveSubsetFonts\\b[^>]*/>", with: "", options: .regularExpression)
            try? strippedPXml.write(toFile: pXmlPath, atomically: true, encoding: .utf8)
        }
        
        // Đóng gói lại file PPTX (KHÔNG đặt read-only — nếu đặt 0444 thì Cmd+S sẽ không ghi được và PowerPoint tự bật Save As)
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryPath = tempDir
        zip.arguments = ["-q", "-r", pptxPath, "."]
        try? zip.run()
        zip.waitUntilExit()
        
        try? FileManager.default.removeItem(atPath: tempDir)
    }
    
    private func watchPowerPoint(tempPptxPath: URL, sessionDir: URL, originalName: String, sessionStartTime: Date, initialFiles: Set<String>, externalSourceURL: URL? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let targetFullName = tempPptxPath.lastPathComponent
            let targetBaseName = tempPptxPath.deletingPathExtension().lastPathComponent
            let sessionFolderName = sessionDir.lastPathComponent
            let targetPath = tempPptxPath.path
            let targetResolvedPath = tempPptxPath.resolvingSymlinksInPath().path
            
            var isOpened = false
            for _ in 0..<400 {
                let checkScript = """
                tell application "Microsoft PowerPoint"
                    set isOpen to false
                    try
                        repeat with p in presentations
                            try
                                set tmpName to (full name of p) as string
                                set pName to (name of p) as string
                                set pPath to tmpName
                                if not (tmpName starts with "/" or tmpName starts with "~") then
                                    try
                                        set pPath to POSIX path of (tmpName as alias)
                                    on error
                                        set pPath to tmpName
                                    end try
                                end if
                                if (pName is "\(targetFullName)" or pName is "\(targetBaseName)" or pName starts with "\(targetBaseName)") or ¬
                                   (tmpName contains "\(sessionFolderName)") or ¬
                                   (pPath contains "\(sessionFolderName)") or ¬
                                   (pPath is "\(targetPath)") or ¬
                                   (pPath is "\(targetResolvedPath)") then
                                    set isOpen to true
                                    exit repeat
                                end if
                            end try
                        end repeat
                    end try
                    return isOpen
                end tell
                """
                if let output = NSAppleScript(source: checkScript)?.executeAndReturnError(nil).stringValue, output == "true" {
                    isOpened = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            if !isOpened {
                self.saveAndCleanup(tempPptxPath: tempPptxPath, sessionDir: sessionDir, originalName: originalName, sessionStartTime: sessionStartTime, initialFiles: initialFiles, externalSourceURL: externalSourceURL)
                return
            }
            
            // Ghi nhận số lượng slide ban đầu để làm chuẩn phát hiện thao tác nhân bản/chèn slide (Cmd+D / Duplicate Slide)
            var initialSlideCount = 0
            let countScript = """
            tell application "Microsoft PowerPoint"
                set sc to 0
                try
                    repeat with p in presentations
                        set tmpName to (full name of p) as string
                        set pName to (name of p) as string
                        if (pName is "\(targetFullName)" or pName is "\(targetBaseName)" or pName starts with "\(targetBaseName)") or ¬
                           (tmpName contains "\(sessionFolderName)") then
                            set sc to count of slides of p
                            exit repeat
                        end if
                    end repeat
                end try
                return sc
            end tell
            """
            if let countStr = NSAppleScript(source: countScript)?.executeAndReturnError(nil).stringValue,
               let countInt = Int(countStr), countInt > 0 {
                initialSlideCount = countInt
                AppLogger.writeLog("Baseline slide count recorded: \(initialSlideCount) for \(targetFullName)")
            }
            
            // Đăng ký bộ lắng nghe phím tắt toàn cục để chặn Cmd+C (Copy) và Cmd+D (Duplicate) trực tiếp khi PowerPoint active
            var keyMonitor: Any? = nil
            DispatchQueue.main.sync {
                keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
                    guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.microsoft.Powerpoint" else { return }
                    if event.modifierFlags.contains(.command) {
                        // Keycode 8 = 'C' (Copy), Keycode 2 = 'D' (Duplicate Slide)
                        if event.keyCode == 8 || event.keyCode == 2 {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("⚠️ BẢO MẬT SLIDELOCK: Bài giảng được bảo vệ bản quyền. Nghiêm cấm sao chép hoặc nhân bản slide!", forType: .string)
                            AppLogger.writeLog("Intercepted hotkey Cmd+\(event.keyCode == 8 ? "C" : "D") in PowerPoint.")
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.statusMessage = "Bài giảng đang mở trong chế độ bảo mật (Đã kích hoạt lá chắn chống sao chép slide)."
            }
            
            var lastPasteboardCount = NSPasteboard.general.changeCount
            var loopIndex = 0
            var stillOpen = true
            while stillOpen {
                self.closeIllegalWindows()
                
                // Giám sát và triệt tiêu clipboard liên tục trong thời gian thực (chống Copy text, shape, slide từ PowerPoint)
                self.sanitizeClipboard(lastChangeCount: &lastPasteboardCount)
                
                // 1. Quét diệt presentation clone và khóa file bị Save As mỗi 200ms (2 vòng lặp)
                if loopIndex % 2 == 0 {
                    stillOpen = self.scanAndKillClones(tempPptxPath: tempPptxPath, sessionDir: sessionDir)
                }
                
                // 2. Quét file descriptor ở cấp Kernel (lsof) để khóa mọi file PPTX/PDF PowerPoint đang mở ngoài cache mỗi 200ms (2 vòng lặp)
                if loopIndex % 2 == 1 {
                    self.scanAndPoisonPowerPointOpenFiles(sessionDir: sessionDir)
                }
                
                // 3. Quét toàn bộ hệ thống file so sánh với snapshot ban đầu để khóa các file mới tạo mỗi 300ms (3 vòng lặp)
                if loopIndex % 3 == 0 {
                    self.scanAndPoisonIllegalFiles(sessionStartTime: sessionStartTime, sessionDir: sessionDir, lessonName: originalName, initialFiles: initialFiles)
                }
                
                // 4. Giám sát số lượng slide: nếu phát hiện số slide tăng lên do Duplicate / Copy-Paste slide, lập tức xóa bỏ slide thừa
                if initialSlideCount > 0 && loopIndex % 2 == 0 {
                    self.preventSlideDuplication(targetFullName: targetFullName, targetBaseName: targetBaseName, sessionFolderName: sessionFolderName, initialCount: initialSlideCount)
                }
                
                if !stillOpen {
                    break
                }
                
                Thread.sleep(forTimeInterval: 0.1)
                loopIndex += 1
            }
            
            if let monitor = keyMonitor {
                DispatchQueue.main.async {
                    NSEvent.removeMonitor(monitor)
                }
            }
            
            // Quét và đầu độc lần cuối trước khi dọn dẹp
            self.scanAndPoisonPowerPointOpenFiles(sessionDir: sessionDir)
            self.scanAndPoisonIllegalFiles(sessionStartTime: sessionStartTime, sessionDir: sessionDir, lessonName: originalName, initialFiles: initialFiles)
            self.saveAndCleanup(tempPptxPath: tempPptxPath, sessionDir: sessionDir, originalName: originalName, sessionStartTime: sessionStartTime, initialFiles: initialFiles, externalSourceURL: externalSourceURL)
        }
    }
    
    private func snapshotExistingFiles() -> Set<String> {
        var existing = Set<String>()
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let appParentDir = Bundle.main.bundleURL.deletingLastPathComponent()
        var scanDirs: [URL] = [
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .musicDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first,
            appParentDir,
            home.appendingPathComponent("Public"),
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/Documents"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/tmp"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/Library/Preferences/AutoRecovery"),
            URL(fileURLWithPath: "/tmp")
        ].compactMap { $0 }
        
        if let volumes = try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for v in volumes {
                if v.lastPathComponent != "Macintosh HD" {
                    scanDirs.append(v)
                }
            }
        }
        
        let targetExts: Set<String> = ["pptx", "ppt", "pptm", "ppsx", "pdf", "key", "odp"]
        for base in scanDirs {
            guard let enumerator = fileManager.enumerator(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            while let fileURL = enumerator.nextObject() as? URL {
                if enumerator.level > 5 {
                    enumerator.skipDescendants()
                    continue
                }
                if targetExts.contains(fileURL.pathExtension.lowercased()) {
                    existing.insert(fileURL.resolvingSymlinksInPath().path)
                }
            }
        }
        
        if let homeFiles = try? fileManager.contentsOfDirectory(at: home, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for f in homeFiles {
                if targetExts.contains(f.pathExtension.lowercased()) {
                    existing.insert(f.resolvingSymlinksInPath().path)
                }
            }
        }
        
        return existing
    }
    
    private func scanAndPoisonPowerPointOpenFiles(sessionDir: URL) {
        let pptApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Powerpoint")
        guard let pptApp = pptApps.first else { return }
        let pid = pptApp.processIdentifier
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-p", "\(pid)", "-F", "n"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return }
        
        let targetExts: Set<String> = ["pptx", "ppt", "pptm", "ppsx", "pdf", "key", "odp"]
        let sessionPath = sessionDir.path
        let sessionResolvedPath = sessionDir.resolvingSymlinksInPath().path
        let cachePath = SecureStorage.cacheDirectory.path
        let cacheResolvedPath = SecureStorage.cacheDirectory.resolvingSymlinksInPath().path
        
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            guard line.starts(with: "n") else { continue }
            let rawPath = String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawPath.isEmpty else { continue }
            
            if rawPath.contains(sessionPath) || rawPath.contains(sessionResolvedPath) ||
               rawPath.contains(cachePath) || rawPath.contains(cacheResolvedPath) ||
               rawPath.contains(".SlideLock_Cache") ||
               rawPath.contains("/Applications/") || rawPath.contains("/System/") ||
               rawPath.contains("/Library/Fonts/") || rawPath.contains("/usr/") ||
               rawPath.contains("/dev/") {
                continue
            }
            
            let fileURL = URL(fileURLWithPath: rawPath)
            let ext = fileURL.pathExtension.lowercased()
            
            if targetExts.contains(ext) {
                self.lockAndEncryptFile(at: fileURL)
            }
        }
    }
    
    private func posixPath(from anyPath: String) -> String {
        let trimmed = anyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.starts(with: "/") {
            return trimmed
        }
        
        // Chuyển đổi HFS path (ví dụ: "Macintosh HD:Users:name:Desktop:file.pptx")
        if trimmed.contains(":") {
            let parts = trimmed.components(separatedBy: ":")
            if parts.count > 1 {
                // Bỏ qua tên Volume đầu tiên (ví dụ: "Macintosh HD")
                let rel = parts.dropFirst().joined(separator: "/")
                let cand1 = "/" + rel
                if FileManager.default.fileExists(atPath: cand1) {
                    return cand1
                }
                let cand2 = "/Volumes/" + trimmed.replacingOccurrences(of: ":", with: "/")
                if FileManager.default.fileExists(atPath: cand2) {
                    return cand2
                }
                return cand1
            }
        }
        
        return trimmed
    }
    
    private func lockAndEncryptFile(at fileURL: URL, destinationURL: URL? = nil) {
        fileLockQueue.sync {
            let resolvedPath = self.posixPath(from: fileURL.resolvingSymlinksInPath().path)
            let targetURL = destinationURL ?? URL(fileURLWithPath: resolvedPath)
            let outPath = targetURL.path
            
            // Tuyệt đối không khóa các file bên trong thư mục cache bảo mật tạm thời của SlideLock!
            guard !resolvedPath.contains(".SlideLock_Cache") else { return }
            guard FileManager.default.fileExists(atPath: resolvedPath) else { return }
            
            // Đợi tối đa 0.3s để đảm bảo PowerPoint đã flush xong dữ liệu ra file
            var fileData: Data? = nil
            for _ in 0..<6 {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: resolvedPath)), data.count > 0 {
                    fileData = data
                    break
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            guard let rawData = fileData, rawData.count > 0 else { return }
            
            // Nếu file đã có header magic của SlideLock (đã được khóa) thì không khóa lặp lại
            if let prefix = String(data: rawData.prefix(128), encoding: .utf8),
               prefix.contains(self.slideLockHeaderMagic) {
                return
            }
            
            let poisonUuid = UUID().uuidString
            let timestamp = ISO8601DateFormatter().string(from: Date())
            
            // Header chứa mã lỗi tường minh và thông điệp bảo mật
            let headerStr = """
            \(self.slideLockHeaderMagic)
            [ERROR_CODE: \(self.slideLockErrorCode)]
            ================================================================================
            ⚠️ CẢNH BÁO BẢO MẬT BẢN QUYỀN SLIDELOCK:
            MÃ LỖI (ERROR CODE): \(self.slideLockErrorCode)
            TRẠNG THÁI: TỆP BÀI GIẢNG ĐÃ BỊ KHÓA BẢN QUYỀN DO PHÁT HIỆN LƯU / SAVE AS TRÁI PHÉP.
            THÔNG BÁO: Tệp này không thể mở bằng Microsoft PowerPoint thông thường.
            BẮT BUỘC PHẢI MỞ THÔNG QUA ỨNG DỤNG SLIDELOCK ĐÃ ĐƯỢC CẤP KEY HỢP LỆ.
            TOKEN BẢO MẬT: \(poisonUuid)
            THỜI GIAN KHÓA: \(timestamp)
            MÃ THIẾT BỊ GỐC: \(MachineID.current)
            ================================================================================
            \(self.slideLockPayloadMarker)
            """
            
            guard let secretData = "12345678901234567890123456789012".data(using: .utf8),
                  let headerData = headerStr.data(using: .utf8) else { return }
            
            let symmetricKey = SymmetricKey(data: secretData)
            let nonce = AES.GCM.Nonce()
            
            do {
                let sealedBox = try AES.GCM.seal(rawData, using: symmetricKey, nonce: nonce)
                guard let combined = sealedBox.combined else { return }
                
                var lockedData = Data()
                lockedData.append(headerData)
                lockedData.append(combined)
                
                try? FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: resolvedPath)
                try lockedData.write(to: targetURL, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: outPath)
                
                AppLogger.writeLog("Locked and encrypted Save As file with error code \(self.slideLockErrorCode) at: \(outPath)")
                
                DispatchQueue.main.async {
                    self.statusMessage = "⚠️ PHÁT HIỆN LƯU / SAVE AS TRÁI PHÉP: Tệp đã được gán mã lỗi và mã hóa bảo vệ. Bắt buộc phải mở qua SlideLock!"
                }
            } catch {
                AppLogger.writeLog("Failed to lock and encrypt file \(resolvedPath): \(error)")
            }
        }
    }
    
    private func sanitizeClipboard(lastChangeCount: inout Int) {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        
        let isPptFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.microsoft.Powerpoint"
        
        // Kiểm tra toàn diện mọi loại dữ liệu đặc thù của slide/shape PowerPoint (kể cả khi PowerPoint chạy ngầm hoặc vừa chuyển app)
        var hasPptData = false
        if let types = pb.types {
            for t in types {
                let raw = t.rawValue.lowercased()
                if raw.contains("powerpoint") || raw.contains("slide") || raw.contains("office") ||
                   raw.contains("presentation") || raw.contains("openxmlformats") ||
                   raw.contains("ms-powerpoint") || raw.contains("microsoft") ||
                   raw.contains("pict") || raw.contains("graphic") || raw.contains("shape") {
                    hasPptData = true
                    break
                }
            }
        }
        
        // Nếu PowerPoint đang active và vừa có thao tác Copy (changeCount thay đổi) HOẶC clipboard chứa đối tượng từ PowerPoint:
        if (isPptFrontmost && currentCount != lastChangeCount) || hasPptData {
            pb.clearContents()
            pb.setString("⚠️ BẢO MẬT SLIDELOCK: Bài giảng được bảo vệ bản quyền. Nghiêm cấm sao chép slide và nội dung!", forType: .string)
            lastChangeCount = pb.changeCount
            AppLogger.writeLog("Blocked unauthorized copy attempt from PowerPoint and sanitized clipboard.")
            DispatchQueue.main.async {
                self.statusMessage = "⚠️ BẢO MẬT BẢN QUYỀN: Đã chặn thao tác sao chép (Copy) slide hoặc nội dung từ PowerPoint!"
            }
        } else if currentCount != lastChangeCount {
            lastChangeCount = currentCount
        }
    }
    
    private func preventSlideDuplication(targetFullName: String, targetBaseName: String, sessionFolderName: String, initialCount: Int) {
        guard initialCount > 0 else { return }
        let checkDupScript = """
        try
            with timeout of 1 second
                tell application "Microsoft PowerPoint"
                    set dupFound to false
                    try
                        repeat with p in presentations
                            set tmpName to (full name of p) as string
                            set pName to (name of p) as string
                            if (pName is "\(targetFullName)" or pName is "\(targetBaseName)" or pName starts with "\(targetBaseName)") or ¬
                               (tmpName contains "\(sessionFolderName)") then
                                set curCount to count of slides of p
                                if curCount > \(initialCount) then
                                    set dupFound to true
                                    repeat with sIdx from curCount down to (\(initialCount) + 1)
                                        try
                                            delete (slide sIdx of p)
                                        end try
                                    end repeat
                                end if
                                exit repeat
                            end if
                        end repeat
                    end try
                    if dupFound then
                        return "DUP_DELETED"
                    else
                        return "OK"
                    end if
                end tell
            end timeout
        on error
            return "ERROR"
        end try
        """
        
        if let res = NSAppleScript(source: checkDupScript)?.executeAndReturnError(nil).stringValue, res == "DUP_DELETED" {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("⚠️ BẢO MẬT SLIDELOCK: Nghiêm cấm sao chép hoặc nhân bản slide!", forType: .string)
            AppLogger.writeLog("Blocked and removed unauthorized duplicated slide in PowerPoint.")
            DispatchQueue.main.async {
                self.statusMessage = "⚠️ PHÁT HIỆN SAO CHÉP SLIDE: Thao tác nhân bản/sao chép slide đã bị chặn và tự động xóa bỏ!"
            }
        }
    }
    
    private func scanAndPoisonIllegalFiles(sessionStartTime: Date, sessionDir: URL, lessonName: String, initialFiles: Set<String>) {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let appParentDir = Bundle.main.bundleURL.deletingLastPathComponent()
        
        var baseDirs: [URL] = [
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .musicDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first,
            appParentDir,
            home.appendingPathComponent("Public"),
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/Library/Preferences/AutoRecovery"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/tmp"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/Documents"),
            URL(fileURLWithPath: "/tmp")
        ].compactMap { $0 }
        
        if let volumes = try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for v in volumes {
                if v.lastPathComponent != "Macintosh HD" {
                    baseDirs.append(v)
                }
            }
        }
        
        let targetExtensions: Set<String> = ["pptx", "ppt", "pptm", "ppsx", "pdf", "key", "odp"]
        let sessionPath = sessionDir.path
        let sessionResolvedPath = sessionDir.resolvingSymlinksInPath().path
        let cachePath = SecureStorage.cacheDirectory.path
        let cacheResolvedPath = SecureStorage.cacheDirectory.resolvingSymlinksInPath().path
        let cleanLessonName = lessonName.replacingOccurrences(of: ".pptx", with: "", options: .caseInsensitive).lowercased()
        
        // 1. Quét sâu (level <= 5) tất cả các thư mục người dùng thường dùng để lưu file
        for dir in baseDirs {
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            while let file = enumerator.nextObject() as? URL {
                if enumerator.level > 5 {
                    enumerator.skipDescendants()
                    continue
                }
                
                let ext = file.pathExtension.lowercased()
                guard targetExtensions.contains(ext) else { continue }
                
                let filePath = file.resolvingSymlinksInPath().path
                if filePath.contains(sessionPath) || filePath.contains(sessionResolvedPath) ||
                   filePath.contains(cachePath) || filePath.contains(cacheResolvedPath) ||
                   filePath.contains(".SlideLock_Cache") {
                    continue
                }
                
                var shouldPoison = false
                
                // A. Nếu file KHÔNG có trong snapshot ban đầu -> 100% file vừa được Save As/Export ra ngoài!
                if !initialFiles.contains(filePath) {
                    shouldPoison = true
                }
                
                // B. File có trong snapshot (tồn tại từ trước) nhưng có timestamp mới SAU khi mở bài.
                // CHỈ poison nếu file KHÔNG có trong snapshot để tránh đầu độc nhầm file AutoRecovery cũ
                // hoặc các file PPT hợp lệ của user đã tồn tại từ trước phiên học.
                // Không cần xử lý thêm ở đây vì điều kiện A đã bao phủ file mới hoàn toàn.
                // Điều kiện B được giữ lại như một lớp bảo vệ phụ nhưng CHỈ áp dụng khi file KHÔNG có trong snapshot.
                if !shouldPoison {
                    if let resourceValues = try? file.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]),
                       let modDate = resourceValues.contentModificationDate ?? resourceValues.creationDate {
                        // Chỉ kích hoạt nếu file KHÔNG có trong snapshot VÀ có timestamp mới (sau khi bắt đầu phiên học)
                        // Dung sai chỉ 5 giây (thay vì 30) để tránh false positive với AutoRecovery cũ
                        if !initialFiles.contains(filePath) && modDate >= sessionStartTime.addingTimeInterval(-5.0) {
                            shouldPoison = true
                        }
                    }
                }
                
                // C. Tên file trùng với tên bài giảng VÀ file KHÔNG có trong snapshot ban đầu.
                // PHẢI check initialFiles để tránh poison file gốc của user đã tồn tại từ trước!
                if !shouldPoison && !cleanLessonName.isEmpty && !initialFiles.contains(filePath) {
                    let fileName = file.deletingPathExtension().lastPathComponent.lowercased()
                    // Tăng độ chính xác: chỉ match khi tên file chứa cleanLessonName (không match ngược)
                    // để tránh trường hợp cleanLessonName ngắn (vd: "a") match vào tên file dài bất kỳ
                    if fileName.contains(cleanLessonName) {
                        shouldPoison = true
                    }
                }
                
                if shouldPoison {
                    self.lockAndEncryptFile(at: file)
                }
            }
        }
        
        // 2. Quét tầng 1 của thư mục Home (nếu người dùng Save As trực tiếp vào ~/)
        if let homeFiles = try? fileManager.contentsOfDirectory(at: home, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey], options: [.skipsHiddenFiles]) {
            for f in homeFiles {
                let ext = f.pathExtension.lowercased()
                if targetExtensions.contains(ext) {
                    let fPath = f.resolvingSymlinksInPath().path
                    // Chỉ khóa nếu file KHÔNG có trong snapshot ban đầu (tức là mới được tạo ra trong phiên học)
                    if !initialFiles.contains(fPath) && !fPath.contains(".SlideLock_Cache") {
                        self.lockAndEncryptFile(at: f)
                    }
                }
            }
        }
    }
    
    private func saveAndCleanup(tempPptxPath: URL, sessionDir: URL, originalName: String, sessionStartTime: Date, initialFiles: Set<String>, externalSourceURL: URL? = nil) {
        Thread.sleep(forTimeInterval: 0.3)
        self.scanAndPoisonPowerPointOpenFiles(sessionDir: sessionDir)
        self.scanAndPoisonIllegalFiles(sessionStartTime: sessionStartTime, sessionDir: sessionDir, lessonName: originalName, initialFiles: initialFiles)
        
        // Nếu phiên làm việc này mở từ một file ngoài (tệp đã khóa riêng lẻ):
        if let sourceURL = externalSourceURL {
            if FileManager.default.fileExists(atPath: tempPptxPath.path) {
                self.lockAndEncryptFile(at: tempPptxPath, destinationURL: sourceURL)
            }
            try? FileManager.default.removeItem(at: sessionDir)
            SecureStorage.cleanupAll()
            DispatchQueue.main.async {
                self.statusMessage = "Đã lưu bản cập nhật và khóa tệp bài giảng an toàn."
                self.isProcessing = false
            }
            return
        }
        
        guard let tempZip = try? getDecryptedZipURL() else {
            try? FileManager.default.removeItem(at: sessionDir)
            return
        }
        
        if FileManager.default.fileExists(atPath: tempPptxPath.path) {
            let renamedPptx = sessionDir.appendingPathComponent(originalName)
            if tempPptxPath.path != renamedPptx.path {
                try? FileManager.default.removeItem(at: renamedPptx)
                try? FileManager.default.copyItem(at: tempPptxPath, to: renamedPptx)
            }
            
            if FileManager.default.fileExists(atPath: renamedPptx.path) {
                // Chạy zip từ trong sessionDir để chỉ cập nhật file bài giảng theo tên tương đối (originalName)
                // Giữ nguyên 100% cấu trúc của archive baigiang.khoa mà không bị nhét thêm đường dẫn thư mục tuyệt đối
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                task.currentDirectoryPath = sessionDir.path
                task.arguments = ["-q", "-u", tempZip.path, originalName]
                try? task.run()
                task.waitUntilExit()
            }
        }
        
        do {
            let zipData = try Data(contentsOf: tempZip)
            
            let secretData = "12345678901234567890123456789012".data(using: .utf8)!
            let symmetricKey = SymmetricKey(data: secretData)
            let nonce = AES.GCM.Nonce()
            
            let sealedBox = try AES.GCM.seal(zipData, using: symmetricKey, nonce: nonce)
            let encryptedData = sealedBox.combined!
            
            let outsideUrl = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("baigiang.khoa")
            let insideUrl = Bundle.main.url(forResource: "baigiang", withExtension: "khoa")
            
            let targetUrl: URL?
            if let custom = customDataURL {
                targetUrl = custom
            } else if FileManager.default.fileExists(atPath: outsideUrl.path) {
                targetUrl = outsideUrl
            } else {
                targetUrl = insideUrl
            }
            
            if let targetUrl = targetUrl {
                try? encryptedData.write(to: targetUrl)
            }
        } catch {
            print("Failed to re-encrypt: \(error)")
        }
        
        try? FileManager.default.removeItem(at: sessionDir)
        SecureStorage.cleanupAll()
        
        DispatchQueue.main.async {
            self.statusMessage = "Đã lưu bản cập nhật và đóng bài giảng an toàn."
            self.isProcessing = false
        }
    }
    
    private func closeIllegalWindows() {
        let script = """
        try
            tell application "System Events"
                set targetProcs to {}
                if exists (application process "Microsoft PowerPoint") then
                    copy (application process "Microsoft PowerPoint") to end of targetProcs
                end if
                if exists (application process "WPS Office") then
                    copy (application process "WPS Office") to end of targetProcs
                end if
                
                repeat with frontApp in targetProcs
                    try
                        repeat with w in (windows of frontApp)
                            set fontHandled to false
                            
                            -- 1. XỬ LÝ POPUP CẢNH BÁO FONT (khi bấm Lưu / Save As trên MacBook đời mới)
                            -- Tự động click "Save Without Fonts" / "Lưu không có phông chữ"
                            -- để lưu bình thường vào cache và triệt tiêu popup, không cho popup chặn tiến trình
                            try
                                if exists (sheet 1 of w) then
                                    set theSheet to sheet 1 of w
                                    repeat with btn in (buttons of theSheet)
                                        try
                                            set btnTitle to (title of btn) as string
                                            if btnTitle contains "Save Without Fonts" or ¬
                                               btnTitle contains "Without Fonts" or ¬
                                               btnTitle contains "Don't Save Fonts" or ¬
                                               btnTitle contains "Don't Embed" or ¬
                                               btnTitle contains "Remove Restricted" or ¬
                                               btnTitle contains "Lưu không có phông" or ¬
                                               btnTitle contains "Không có phông" or ¬
                                               btnTitle contains "Không nhúng" or ¬
                                               btnTitle contains "Không lưu phông" or ¬
                                               btnTitle contains "Không lưu" then
                                                click btn
                                                set fontHandled to true
                                                exit repeat
                                            end if
                                        end try
                                    end repeat
                                    
                                    -- Nếu là sheet khác không phải font (Save As / Export / Print sheet)
                                    if not fontHandled then
                                        try
                                            click button "Cancel" of theSheet
                                        end try
                                        try
                                            click button "Hủy" of theSheet
                                        end try
                                        try
                                            click button "Don't Save" of theSheet
                                        end try
                                        try
                                            repeat with g in (groups of theSheet)
                                                try
                                                    click button "Cancel" of g
                                                end try
                                                try
                                                    click button "Hủy" of g
                                                end try
                                            end repeat
                                        end try
                                        delay 0.02
                                        key code 53 -- Phím ESCape trực tiếp từ System Events
                                    end if
                                end if
                            end try
                            
                            -- Kiểm tra trong chính window w (khi popup font là AXDialog hoặc Alert Window độc lập)
                            if not fontHandled then
                                try
                                    repeat with btn in (buttons of w)
                                        try
                                            set btnTitle to (title of btn) as string
                                            if btnTitle contains "Save Without Fonts" or ¬
                                               btnTitle contains "Without Fonts" or ¬
                                               btnTitle contains "Don't Save Fonts" or ¬
                                               btnTitle contains "Don't Embed" or ¬
                                               btnTitle contains "Remove Restricted" or ¬
                                               btnTitle contains "Lưu không có phông" or ¬
                                               btnTitle contains "Không có phông" or ¬
                                               btnTitle contains "Không nhúng" or ¬
                                               btnTitle contains "Không lưu phông" or ¬
                                               btnTitle contains "Không lưu" then
                                                click btn
                                                set fontHandled to true
                                                exit repeat
                                            end if
                                        end try
                                    end repeat
                                end try
                            end if
                            
                            -- 2. NẾU KHÔNG PHẢI POPUP FONT, KIỂM TRA XEM CÓ PHẢI CỬA SỔ LƯU / XUẤT / IN BẤT HỢP PHÁP KHÔNG
                            if not fontHandled then
                                try
                                    set wName to ""
                                    try
                                        set wName to (name of w) as string
                                    end try
                                    set isIllegalWin to false
                                    
                                    if wName is not missing value and wName is not "" then
                                        if wName contains "Save" or wName contains "Lưu" or ¬
                                           wName contains "Export" or wName contains "Xuất" or ¬
                                           wName contains "Print" or wName contains "In " or wName is "In" or ¬
                                           wName contains "Duplicate" or wName contains "Bản sao" or ¬
                                           wName contains "Nhân bản" or ¬
                                           wName contains "Move" or wName contains "Di chuyển" or ¬
                                           wName contains "Share" or wName contains "Chia sẻ" or ¬
                                           wName contains "Publish" or wName contains "Phát hành" or ¬
                                           wName contains "Save a Copy" or wName contains "Lưu một bản sao" then
                                            set isIllegalWin to true
                                        end if
                                    end if
                                    
                                    -- Kiểm tra nếu cửa sổ có subrole là AXSavePanel hoặc AXDialog
                                    if not isIllegalWin then
                                        try
                                            set sRole to (subrole of w) as string
                                            if sRole is "AXSavePanel" or sRole is "AXDialog" then
                                                set isIllegalWin to true
                                            end if
                                        end try
                                    end if
                                    
                                    -- Kiểm tra nếu cửa sổ không có tên nhưng có nút Save hoặc Cancel (NSSavePanel độc lập)
                                    if not isIllegalWin and (wName is "" or wName is " ") then
                                        try
                                            repeat with btn in (buttons of w)
                                                try
                                                    set bTitle to (title of btn) as string
                                                    if bTitle is "Save" or bTitle is "Lưu" or bTitle is "Export" or bTitle is "Xuất" then
                                                        set isIllegalWin to true
                                                        exit repeat
                                                    end if
                                                end try
                                            end repeat
                                        end try
                                    end if
                                    
                                    if isIllegalWin then
                                        try
                                            click button "Cancel" of w
                                        end try
                                        try
                                            click button "Hủy" of w
                                        end try
                                        try
                                            repeat with g in (groups of w)
                                                try
                                                    click button "Cancel" of g
                                                end try
                                                try
                                                    click button "Hủy" of g
                                                end try
                                            end repeat
                                        end try
                                        delay 0.02
                                        key code 53 -- Phím ESCape trực tiếp từ System Events
                                    end if
                                end try
                            end if
                        end repeat
                    end try
                end repeat
                
                -- 3. ĐÓNG CỬA SỔ FINDER NẾU CỐ TÌNH MỞ VÀO THƯ MỤC CACHE BẢO MẬT
                if exists (application process "Finder") then
                    tell application "Finder"
                        repeat with fw in (every window)
                            try
                                set fTarget to (target of fw) as string
                                if fTarget contains ".SlideLock_Cache" then
                                    close fw
                                end if
                            end try
                        end repeat
                    end tell
                end if
                
            end tell
            return "SUCCESS"
        on error errMsg number errNum
            return "ERROR: " & errMsg & " (" & errNum & ")"
        end try
        """
        if let scriptObj = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            let desc = scriptObj.executeAndReturnError(&errorInfo)
            if let output = desc.stringValue, output.starts(with: "ERROR") {
                AppLogger.writeLog("AppleScript Exception in closeIllegalWindows: \(output)")
            } else if let err = errorInfo {
                AppLogger.writeLog("Internal Error in closeIllegalWindows: \(err)")
            }
        }
    }
    
    private func scanAndKillClones(tempPptxPath: URL, sessionDir: URL) -> Bool {
        let sessionFolderName = sessionDir.lastPathComponent
        let targetPath = tempPptxPath.path
        let targetResolvedPath = tempPptxPath.resolvingSymlinksInPath().path

        let protectScript = """
        try
            with timeout of 1 second
                tell application "Microsoft PowerPoint"
                    set originalOpen to false
                    set clones to {}
                    
                    try
                        repeat with p in presentations
                            set isOriginal to false
                            set pFullName to ""
                            set pName to ""
                            
                            try
                                set pName to (name of p) as string
                            end try
                            try
                                set pFullName to (full name of p) as string
                            end try
                            
                            set pPosix to ""
                            if pFullName starts with "/" or pFullName starts with "~" then
                                set pPosix to pFullName
                            else if pFullName is not "" then
                                try
                                    set pPosix to POSIX path of (pFullName as alias)
                                on error
                                    try
                                        tell application "System Events"
                                            set pPosix to POSIX path of disk item pFullName
                                        end tell
                                    on error
                                        -- Chuyển đổi thủ công HFS path sang POSIX
                                        if pFullName contains ":" then
                                            set AppleScript's text item delimiters to ":"
                                            set hfsParts to text items of pFullName
                                            set AppleScript's text item delimiters to ""
                                            if (count of hfsParts) > 1 then
                                                set AppleScript's text item delimiters to "/"
                                                set restParts to (items 2 thru -1 of hfsParts) as string
                                                set AppleScript's text item delimiters to ""
                                                set pPosix to "/" & restParts
                                            else
                                                set pPosix to pFullName
                                            end if
                                        else
                                            set pPosix to pFullName
                                        end if
                                    end try
                                end try
                            end if
                            
                            -- Nhận diện presentation bài giảng chính xác:
                            -- BẮT BUỘC đường dẫn phải nằm trong sessionFolderName hoặc khớp chính xác targetPath!
                            if (pFullName contains "\(sessionFolderName)") or ¬
                               (pPosix contains "\(sessionFolderName)") or ¬
                               (pPosix is "\(targetPath)") or ¬
                               (pPosix is "\(targetResolvedPath)") then
                                set isOriginal to true
                                set originalOpen to true
                            end if
                            
                            -- Mọi presentation khác không phải bài giảng gốc đều bị đóng không lưu ngay lập tức
                            if not isOriginal then
                                try
                                    close p saving no
                                end try
                                
                                if pPosix is not "" and not (pPosix contains "\(sessionFolderName)") and not (pPosix contains ".SlideLock_Cache") and (pPosix starts with "/") then
                                    copy pPosix to end of clones
                                else if pFullName is not "" and not (pFullName contains "\(sessionFolderName)") then
                                    copy pFullName to end of clones
                                end if
                            end if
                        end repeat
                    end try
                    
                    set output to ""
                    if originalOpen then 
                        set output to "OPEN###"
                    else
                        set output to "CLOSED###"
                    end if
                    
                    repeat with c in clones
                        set output to output & c & "|"
                    end repeat
                    return output
                end tell
            end timeout
        on error errMsg number errNum
            return "ERROR###" & errMsg & "###" & errNum
        end try
        """
        
        var shouldContinue = false
        var errorInfo: NSDictionary?
        if let output = NSAppleScript(source: protectScript)?.executeAndReturnError(&errorInfo).stringValue {
            if output.starts(with: "ERROR") {
                AppLogger.writeLog("AppleScript Exception in scanAndKillClones: \(output)")
                return true
            }
            
            let parts = output.components(separatedBy: "###")
            if parts.count >= 2 {
                let status = parts[0]
                shouldContinue = (status == "OPEN")
                
                let paths = parts[1].components(separatedBy: "|")
                var foundClones = false
                for path in paths {
                    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        foundClones = true
                        let resolvedPath = self.posixPath(from: trimmed)
                        self.lockAndEncryptFile(at: URL(fileURLWithPath: resolvedPath))
                    }
                }
                if foundClones {
                    DispatchQueue.main.async {
                        self.statusMessage = "CẢNH BÁO BẢO MẬT: Phát hiện lưu/sao chép bài giảng! Bản sao đã bị gán mã lỗi và mã hóa bảo vệ. Bắt buộc phải mở qua SlideLock."
                    }
                }
            }
        }
        return shouldContinue
    }
}


struct SecurityTag: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.14))
        .foregroundColor(color)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.3), lineWidth: 1))
    }
}
