import SwiftUI
import AppKit
import Foundation
import CryptoKit
import CoreGraphics

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
    @State private var isHoveringActionBtn: Bool = false
    
    private let slideLockHeaderMagic = "SLIDELOCK_ENCRYPTED_FILE_V1"
    private let slideLockPayloadMarker = "---SLIDELOCK_PAYLOAD_BEGIN---\n"
    private let slideLockFatalHeaderMagic = "SLIDELOCK_FATAL_ERROR_V2"
    private let slideLockCorruptMarker = "---SLIDELOCK_CORRUPTED_PAYLOAD_BEGIN---\n"
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
                            .progressViewStyle(CircularProgressViewStyle())
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
                            SecurityTag(icon: "doc.on.doc", text: "Chống Copy Slide", color: Color(red: 0.35, green: 0.35, blue: 0.90))
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
        if let url = URL(string: "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Accessibility") {
            if NSWorkspace.shared.open(url) { return }
        }
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
            let prefixStr = String(data: fileData.prefix(512), encoding: .utf8) ?? ""
            
            // 1. Chặn tuyệt đối và báo lỗi nếu tệp là bản Save As trái phép đã bị gán mã lỗi và phá hủy
            if prefixStr.contains(self.slideLockErrorCode) || prefixStr.contains("UNAUTHORIZED_SAVE_AS") || prefixStr.contains("PERMANENTLY_CORRUPTED") || prefixStr.contains(self.slideLockFatalHeaderMagic) {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "⛔ TỆP ĐÃ BỊ HỦY BỎ VÀ KHÓA VĨNH VIỄN: Phát hiện tệp này bị gán mã lỗi do thao tác Save As trái phép (\(self.slideLockErrorCode)). Không thể mở lại!"
                }
                return
            }
            
            // 2. Mở tệp mã hóa hợp lệ của ứng dụng SlideLock
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
                guard payload.count > 28 else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.statusMessage = "Tệp bị khóa nhưng dữ liệu không hợp lệ."
                    }
                    return
                }
                
                let keySeed = "12345678901234567890123456789012:" + MachineID.current
                let keyHash = SHA256.hash(data: Data(keySeed.utf8))
                let symmetricKey = SymmetricKey(data: Data(keyHash))
                do {
                    let sealedBox = try AES.GCM.SealedBox(combined: payload)
                    pptxData = try AES.GCM.open(sealedBox, using: symmetricKey)
                } catch {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.statusMessage = "KHÔNG THỂ MỞ: Tệp này đã bị khóa theo phần cứng của máy tính khác. Bạn không thể sử dụng tệp này!"
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
                
                self.watchPowerPoint(tempPptxPath: extractURL, sessionDir: sessionFolder, originalName: safeName, lessonDisplayName: url.deletingPathExtension().lastPathComponent, sessionStartTime: sessionStartTime, initialFiles: initialFiles, externalSourceURL: url)
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
        
        var bundleUrl: URL? = nil
        if let custom = customDataURL {
            bundleUrl = custom
        } else if FileManager.default.fileExists(atPath: outsideUrl.path) {
            bundleUrl = outsideUrl
        } else if let inside = insideUrl {
            bundleUrl = inside
        } else {
            // TỰ ĐỘNG TÌM KIẾM baigiang.khoa khi macOS kích hoạt App Translocation
            let home = FileManager.default.homeDirectoryForCurrentUser
            let candidateDirs: [URL] = [
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Desktop"),
                home.appendingPathComponent("Documents"),
                URL(fileURLWithPath: "/Applications")
            ]
            for dir in candidateDirs {
                let directFile = dir.appendingPathComponent("baigiang.khoa")
                if FileManager.default.fileExists(atPath: directFile.path) {
                    bundleUrl = directFile
                    break
                }
                let subFolderFile = dir.appendingPathComponent("KhoaHoc_Mac/baigiang.khoa")
                if FileManager.default.fileExists(atPath: subFolderFile.path) {
                    bundleUrl = subFolderFile
                    break
                }
                if let subs = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for sub in subs {
                        let cand = sub.appendingPathComponent("baigiang.khoa")
                        if FileManager.default.fileExists(atPath: cand.path) {
                            bundleUrl = cand
                            break
                        }
                    }
                }
                if bundleUrl != nil { break }
            }
        }
        
        guard let finalBundleUrl = bundleUrl, FileManager.default.fileExists(atPath: finalBundleUrl.path) else {
            throw AppError.fileNotFound
        }
        let bundleUrlFinal = finalBundleUrl
        
        guard let data = try? Data(contentsOf: bundleUrlFinal) else { throw AppError.fileNotFound }
        
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
                
                self.watchPowerPoint(tempPptxPath: extractURL, sessionDir: sessionFolder, originalName: lesson.safeName, lessonDisplayName: lesson.displayName, sessionStartTime: sessionStartTime, initialFiles: initialFiles)
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
            strippedPXml = strippedPXml.replacingOccurrences(of: "(?is)<p:embedTrueTypeFonts\\b[^>]*>.*?</p:embedTrueTypeFonts>", with: "", options: .regularExpression)
            strippedPXml = strippedPXml.replacingOccurrences(of: "(?is)<p:embedTrueTypeFonts\\b[^>]*/>", with: "", options: .regularExpression)
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
    
    private func watchPowerPoint(tempPptxPath: URL, sessionDir: URL, originalName: String, lessonDisplayName: String = "", sessionStartTime: Date, initialFiles: Set<String>, externalSourceURL: URL? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let targetFullName = tempPptxPath.lastPathComponent
            let targetBaseName = tempPptxPath.deletingPathExtension().lastPathComponent
            let sessionFolderName = sessionDir.lastPathComponent
            let targetPath = tempPptxPath.path
            let targetResolvedPath = tempPptxPath.resolvingSymlinksInPath().path
            let cleanDisplayName = lessonDisplayName.replacingOccurrences(of: ".pptx", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanOriginalName = originalName.replacingOccurrences(of: ".pptx", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
            
            AppLogger.writeLog("Starting watchPowerPoint for '\(targetFullName)', original: '\(originalName)', display: '\(lessonDisplayName)'")
            
            // =========================================================================
            // BƯỚC 1: KÍCH HOẠT TOÀN BỘ HỆ THỐNG BẢO VỆ NGAY LẬP TỨC (KHÔNG CHỜ ĐỢI)
            // =========================================================================
            
            // 1.1 CGEventTap chặn phím tắt Cmd+C, Cmd+X, Cmd+D, Cmd+Shift+S, Cmd+P trực tiếp ở tầng OS
            var eventTapSource: CFRunLoopSource? = nil
            var machPort: CFMachPort? = nil
            
            let eventMask = (1 << CGEventType.keyDown.rawValue)
            let tapCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .keyDown {
                    let flags = event.flags
                    if flags.contains(.maskCommand) {
                        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                        let isShift = flags.contains(.maskShift)
                        // 8 = C (Copy), 7 = X (Cut), 2 = D (Duplicate), 35 = P (Print), 1 = S (với Shift: Save As)
                        if keyCode == 8 || keyCode == 7 || keyCode == 2 || keyCode == 35 || (keyCode == 1 && isShift) {
                            if let frontApp = NSWorkspace.shared.frontmostApplication,
                               frontApp.bundleIdentifier == "com.microsoft.Powerpoint" {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("⚠️ BẢO MẬT SLIDELOCK: Bài giảng được bảo vệ bản quyền. Nghiêm cấm sao chép nội dung!", forType: .string)
                                return nil // Nuốt sự kiện hoàn toàn, PowerPoint không nhận được phím!
                            }
                        }
                    }
                }
                return Unmanaged.passRetained(event)
            }
            
            // Thử cgSessionEventTap trước (chuẩn cho user session trên macOS), nếu nil fallback sang cghidEventTap
            var tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: tapCallback,
                userInfo: nil
            )
            if tap == nil {
                tap = CGEvent.tapCreate(
                    tap: .cghidEventTap,
                    place: .headInsertEventTap,
                    options: .defaultTap,
                    eventsOfInterest: CGEventMask(eventMask),
                    callback: tapCallback,
                    userInfo: nil
                )
            }
            
            if let tap = tap {
                machPort = tap
                let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                eventTapSource = src
                CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                AppLogger.writeLog("CGEventTap successfully active to block Copy, Duplicate & Save As.")
            } else {
                AppLogger.writeLog("Notice: CGEventTap nil - accessibility event monitor will serve as secondary guard.")
            }
            
            // 1.2 Bộ lắng nghe phím tắt toàn cục bổ trợ
            var keyMonitor: Any? = nil
            DispatchQueue.main.sync {
                keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
                    guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.microsoft.Powerpoint" else { return }
                    if event.modifierFlags.contains(.command) {
                        let isShift = event.modifierFlags.contains(.shift)
                        if event.keyCode == 8 || event.keyCode == 7 || event.keyCode == 2 || event.keyCode == 35 || (event.keyCode == 1 && isShift) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("⚠️ BẢO MẬT SLIDELOCK: Bài giảng được bảo vệ bản quyền. Nghiêm cấm sao chép hoặc lưu bản sao!", forType: .string)
                            AppLogger.writeLog("Intercepted hotkey Cmd+\(event.keyCode) in PowerPoint.")
                        }
                    }
                }
            }
            
            // 1.3 Timer siêu tốc quét và triệt tiêu clipboard liên tục mỗi 15ms (chống Right-Click Copy, Menu Copy, Drag-Drop)
            let clipboardTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
            var lastPasteboardCount = NSPasteboard.general.changeCount
            clipboardTimer.schedule(deadline: .now(), repeating: .milliseconds(15))
            clipboardTimer.setEventHandler {
                let pb = NSPasteboard.general
                let currentCount = pb.changeCount
                if currentCount != lastPasteboardCount {
                    let isPptFront = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.microsoft.Powerpoint"
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
                    if isPptFront || hasPptData {
                        pb.clearContents()
                        pb.setString("⚠️ BẢO MẬT SLIDELOCK: Bài giảng được bảo vệ bản quyền. Nghiêm cấm sao chép slide và nội dung!", forType: .string)
                        lastPasteboardCount = pb.changeCount
                    } else {
                        lastPasteboardCount = currentCount
                    }
                }
            }
            clipboardTimer.resume()
            
            DispatchQueue.main.async {
                self.statusMessage = "Bài giảng đang mở trong chế độ bảo mật (Đã kích hoạt lá chắn chống sao chép slide & chống Save As)."
            }
            
            // =========================================================================
            // BƯỚC 2: VÒNG LẶP GIÁM SÁT THỜI GIAN THỰC (REALTIME PROTECTION LOOP)
            // =========================================================================
            var initialSlideCount = 0
            var emptyPresentationCount = 0
            var loopIndex = 0
            var stillOpen = true
            
            while stillOpen {
                // Kiểm tra xem ứng dụng PowerPoint có còn đang chạy không
                let pptApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Powerpoint")
                if pptApps.isEmpty {
                    AppLogger.writeLog("Microsoft PowerPoint application terminated by user.")
                    stillOpen = false
                    break
                }
                
                // 1. Tự động đóng mọi popup/dialog nguy hiểm (Save with Fonts, Save As, Export, Print)
                self.closeIllegalWindows()
                
                // 2. Giám sát và triệt tiêu clipboard liên tục
                self.sanitizeClipboard(lastChangeCount: &lastPasteboardCount)
                
                // 3. Quét diệt presentation clone / Save As và khóa file mỗi 200ms
                if loopIndex % 2 == 0 {
                    let isOriginalOpen = self.scanAndKillClones(tempPptxPath: tempPptxPath, sessionDir: sessionDir, lessonDisplayName: lessonDisplayName, originalName: originalName)
                    if !isOriginalOpen {
                        emptyPresentationCount += 1
                        // Chỉ coi là đã kết thúc bài giảng nếu PowerPoint không có bài giảng nào trong 15 lần quét liên tiếp (1.5s)
                        if emptyPresentationCount >= 15 {
                            stillOpen = false
                            break
                        }
                    } else {
                        emptyPresentationCount = 0
                    }
                }
                
                // 4. Quét file descriptor ở cấp Kernel (lsof) để phát hiện và khóa ngay file PowerPoint đang ghi ngoài cache
                if loopIndex % 2 == 1 {
                    self.scanAndPoisonPowerPointOpenFiles(sessionDir: sessionDir)
                }
                
                // 5. Quét toàn bộ hệ thống file so sánh với snapshot ban đầu để khóa file mới tạo
                if loopIndex % 2 == 0 {
                    self.scanAndPoisonIllegalFiles(sessionStartTime: sessionStartTime, sessionDir: sessionDir, lessonName: originalName, initialFiles: initialFiles)
                }
                
                // 6. Ghi nhận số lượng slide ban đầu và tự động xóa bỏ slide nhân bản thừa (Cmd+D / Copy-Paste slide)
                if initialSlideCount == 0 {
                    initialSlideCount = self.fetchSlideCount(targetFullName: targetFullName, targetBaseName: targetBaseName, originalName: originalName, cleanDisplayName: cleanDisplayName, cleanOriginalName: cleanOriginalName, sessionFolderName: sessionFolderName)
                    if initialSlideCount > 0 {
                        AppLogger.writeLog("Baseline slide count successfully recorded: \(initialSlideCount)")
                    }
                } else if loopIndex % 2 == 0 {
                    self.preventSlideDuplication(targetFullName: targetFullName, targetBaseName: targetBaseName, originalName: originalName, cleanDisplayName: cleanDisplayName, cleanOriginalName: cleanOriginalName, sessionFolderName: sessionFolderName, initialCount: initialSlideCount)
                }
                
                Thread.sleep(forTimeInterval: 0.1)
                loopIndex += 1
            }
            
            // =========================================================================
            // BƯỚC 3: DỌN DẸP VÀ ĐÓNG GÓI BẢO MẬT SAU KHI KẾT THÚC PHIÊN HỌC
            // =========================================================================
            clipboardTimer.cancel()
            if let tap = machPort {
                CGEvent.tapEnable(tap: tap, enable: false)
                if let src = eventTapSource {
                    CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                }
            }
            if let monitor = keyMonitor {
                DispatchQueue.main.async {
                    NSEvent.removeMonitor(monitor)
                }
            }
            
            // Quét và đầu độc lần cuối trước khi dọn dẹp để đảm bảo không file Save As nào thoát
            self.scanAndPoisonPowerPointOpenFiles(sessionDir: sessionDir)
            self.scanAndPoisonIllegalFiles(sessionStartTime: sessionStartTime, sessionDir: sessionDir, lessonName: originalName, initialFiles: initialFiles)
            self.saveAndCleanup(tempPptxPath: tempPptxPath, sessionDir: sessionDir, originalName: originalName, sessionStartTime: sessionStartTime, initialFiles: initialFiles, externalSourceURL: externalSourceURL)
        }
    }
    
    private func fetchSlideCount(targetFullName: String, targetBaseName: String, originalName: String, cleanDisplayName: String, cleanOriginalName: String, sessionFolderName: String) -> Int {
        let countScript = """
        try
            with timeout of 1 second
                tell application "Microsoft PowerPoint"
                    set sc to 0
                    try
                        repeat with p in presentations
                            set pName to (name of p) as string
                            set tmpName to (full name of p) as string
                            if (pName is "\(targetFullName)" or pName is "\(targetBaseName)" or ¬
                                pName is "\(originalName)" or pName is "\(cleanDisplayName)" or ¬
                                pName contains "\(cleanDisplayName)" or pName contains "\(cleanOriginalName)" or ¬
                                tmpName contains "\(sessionFolderName)" or tmpName contains ".SlideLock_Cache" or ¬
                                (count of presentations) is 1) then
                                set sc to count of slides of p
                                exit repeat
                            end if
                        end repeat
                    end try
                    return sc
                end tell
            end timeout
        on error
            return 0
        end try
        """
        if let countStr = NSAppleScript(source: countScript)?.executeAndReturnError(nil).stringValue,
           let countInt = Int(countStr), countInt > 0 {
            return countInt
        }
        return 0
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
               rawPath.contains("/Library/Containers/com.microsoft.Powerpoint/") ||
               rawPath.contains("/Applications/") || rawPath.contains("/System/") ||
               rawPath.contains("/Library/Fonts/") || rawPath.contains("/usr/") ||
               rawPath.contains("/dev/") {
                continue
            }
            
            let fileURL = URL(fileURLWithPath: rawPath)
            let ext = fileURL.pathExtension.lowercased()
            
            if targetExts.contains(ext) {
                self.lockAndCorruptIllegalSaveAs(at: fileURL)
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
    
    private func lockAndCorruptIllegalSaveAs(at fileURL: URL) {
        fileLockQueue.sync {
            let resolvedPath = self.posixPath(from: fileURL.resolvingSymlinksInPath().path)
            let targetURL = URL(fileURLWithPath: resolvedPath)
            let outPath = targetURL.path
            
            // Tuyệt đối không can thiệp vào file bên trong thư mục cache bảo mật tạm thời của SlideLock!
            guard !resolvedPath.contains(".SlideLock_Cache") else { return }
            guard FileManager.default.fileExists(atPath: resolvedPath) else { return }
            
            var rawData = (try? Data(contentsOf: URL(fileURLWithPath: resolvedPath))) ?? Data()
            if rawData.isEmpty {
                for _ in 0..<6 {
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: resolvedPath)), data.count > 0 {
                        rawData = data
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
            if rawData.isEmpty {
                rawData = "SLIDELOCK_UNAUTHORIZED_FILE_DATA_DESTROYED".data(using: .utf8)!
            }
            
            // Nếu file đã có mã lỗi của SlideLock (đã bị vô hiệu hóa) thì không thực hiện lại
            if let prefix = String(data: rawData.prefix(256), encoding: .utf8),
               prefix.contains(self.slideLockErrorCode) {
                return
            }
            
            let poisonUuid = UUID().uuidString
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let machineId = MachineID.current
            
            // Header chứa mã lỗi tường minh và thông báo vi phạm bản quyền nghiêm trọng
            let headerStr = """
            \(self.slideLockFatalHeaderMagic)
            [ERROR_CODE: \(self.slideLockErrorCode)]
            [STATUS: FILE_PERMANENTLY_CORRUPTED_AND_LOCKED]
            [VIOLATION: UNAUTHORIZED_SAVE_AS_DETECTED]
            ================================================================================
            ⚠️ CẢNH BÁO BẢO MẬT BẢN QUYỀN SLIDELOCK:
            MÃ LỖI (ERROR CODE): \(self.slideLockErrorCode)
            TRẠNG THÁI: TỆP BÀI GIẢNG ĐÃ BỊ GÁN MÃ LỖI VÀ PHÁ HỦY DO HÀNH VI SAVE AS TRÁI PHÉP.
            HẬU QUẢ: Toàn bộ cấu trúc OpenXML/ZIP đã bị phá hủy và mã hóa xáo trộn vĩnh viễn.
            TỆP NÀY HOÀN TOÀN KHÔNG THỂ MỞ ĐƯỢC TRÊN MICROSOFT POWERPOINT (BÁO LỖI CORRUPT FILE).
            TỆP NÀY CŨNG KHÔNG THỂ MỞ ĐƯỢC TRÊN SLIDELOCK HAY BẤT KỲ ỨNG DỤNG NÀO KHÁC.
            TOKEN BẢO MẬT: \(poisonUuid)
            THỜI GIAN KHÓA: \(timestamp)
            MÃ THIẾT BỊ: \(machineId)
            ================================================================================
            \(self.slideLockCorruptMarker)
            """
            
            // Sinh khóa ngẫu nhiên ném đi (throwaway random key) để mã hóa phá hủy payload không thể phục hồi
            let randomThrowawayKey = SymmetricKey(size: .bits256)
            let nonce = AES.GCM.Nonce()
            
            do {
                let sealedBox = try AES.GCM.seal(rawData, using: randomThrowawayKey, nonce: nonce)
                guard let combined = sealedBox.combined,
                      let headerData = headerStr.data(using: .utf8) else { return }
                
                var corruptData = Data()
                corruptData.append(headerData)
                corruptData.append(combined)
                
                // Gỡ cờ bảo vệ uchg (nếu có) trước khi ghi đè
                let unprot = Process()
                unprot.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
                unprot.arguments = ["noschg,nouchg", resolvedPath]
                try? unprot.run()
                unprot.waitUntilExit()
                
                try? FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: resolvedPath)
                try corruptData.write(to: targetURL, options: .atomic)
                
                // Khóa chặt tệp ở cấp filesystem: chỉ đọc 0444 và gắn cờ uchg (User Immutable)
                try? FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: outPath)
                let lockProc = Process()
                lockProc.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
                lockProc.arguments = ["uchg", outPath]
                try? lockProc.run()
                lockProc.waitUntilExit()
                
                AppLogger.writeLog("Permanently corrupted unauthorized Save As file with error code \(self.slideLockErrorCode) at: \(outPath)")
                
                DispatchQueue.main.async {
                    self.statusMessage = "⚠️ PHÁT HIỆN LƯU / SAVE AS TRÁI PHÉP: Tệp đã bị gán mã lỗi \(self.slideLockErrorCode) và phá hủy hoàn toàn. Tệp không thể mở lại!"
                }
                
                // Kiểm tra phụ sau 0.3s để đảm bảo PowerPoint không flush đè lại
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                    if let checkData = try? Data(contentsOf: targetURL), checkData.count > 0 {
                        let checkPrefix = String(data: checkData.prefix(256), encoding: .utf8) ?? ""
                        if !checkPrefix.contains(self.slideLockErrorCode) {
                            let unprot2 = Process()
                            unprot2.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
                            unprot2.arguments = ["noschg,nouchg", outPath]
                            try? unprot2.run()
                            unprot2.waitUntilExit()
                            
                            try? corruptData.write(to: targetURL, options: .atomic)
                            try? FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: outPath)
                            let lk2 = Process()
                            lk2.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
                            lk2.arguments = ["uchg", outPath]
                            try? lk2.run()
                            lk2.waitUntilExit()
                        }
                    }
                }
            } catch {
                AppLogger.writeLog("Failed to corrupt file \(resolvedPath): \(error)")
            }
        }
    }
    
    private func encryptLegitimateExternalFile(at tempURL: URL, destinationURL: URL) {
        fileLockQueue.sync {
            let resolvedPath = self.posixPath(from: tempURL.resolvingSymlinksInPath().path)
            let outPath = destinationURL.resolvingSymlinksInPath().path
            guard FileManager.default.fileExists(atPath: resolvedPath) else { return }
            guard let rawData = try? Data(contentsOf: URL(fileURLWithPath: resolvedPath)), rawData.count > 0 else { return }
            
            let machineId = MachineID.current
            let keySeed = "12345678901234567890123456789012:" + machineId
            let keyHash = SHA256.hash(data: Data(keySeed.utf8))
            let symmetricKey = SymmetricKey(data: Data(keyHash))
            
            let headerStr = """
            \(self.slideLockHeaderMagic)
            MÃ THIẾT BỊ: \(machineId)
            \(self.slideLockPayloadMarker)
            """
            guard let headerData = headerStr.data(using: .utf8) else { return }
            let nonce = AES.GCM.Nonce()
            do {
                let sealedBox = try AES.GCM.seal(rawData, using: symmetricKey, nonce: nonce)
                guard let combined = sealedBox.combined else { return }
                var lockedData = Data()
                lockedData.append(headerData)
                lockedData.append(combined)
                try? FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: outPath)
                try lockedData.write(to: destinationURL, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: outPath)
                AppLogger.writeLog("Successfully updated and re-encrypted legitimate single file at: \(outPath)")
            } catch {
                AppLogger.writeLog("Failed to update legitimate file: \(error)")
            }
        }
    }
    
    private func sanitizeClipboard(lastChangeCount: inout Int) {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        
        let isPptFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.microsoft.Powerpoint"
        
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
    
    private func preventSlideDuplication(targetFullName: String, targetBaseName: String, originalName: String, cleanDisplayName: String, cleanOriginalName: String, sessionFolderName: String, initialCount: Int) {
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
                            if (pName is "\(targetFullName)" or pName is "\(targetBaseName)" or ¬
                                pName is "\(originalName)" or pName is "\(cleanDisplayName)" or ¬
                                pName contains "\(cleanDisplayName)" or pName contains "\(cleanOriginalName)" or ¬
                                tmpName contains "\(sessionFolderName)" or tmpName contains ".SlideLock_Cache" or ¬
                                (count of presentations) is 1) then
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
        
        // 1. Quét sâu tất cả các thư mục người dùng thường dùng để lưu file
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
                
                // B. Kiểm tra ngày tạo / chỉnh sửa mới hơn thời điểm mở bài
                if !shouldPoison {
                    if let resourceValues = try? file.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]),
                       let modDate = resourceValues.contentModificationDate ?? resourceValues.creationDate {
                        if !initialFiles.contains(filePath) && modDate >= sessionStartTime.addingTimeInterval(-5.0) {
                            shouldPoison = true
                        }
                    }
                }
                
                // C. Tên file chứa tên bài giảng và không có trong snapshot ban đầu
                if !shouldPoison && !cleanLessonName.isEmpty && !initialFiles.contains(filePath) {
                    let fileName = file.deletingPathExtension().lastPathComponent.lowercased()
                    if fileName.contains(cleanLessonName) {
                        shouldPoison = true
                    }
                }
                
                if shouldPoison {
                    self.lockAndCorruptIllegalSaveAs(at: file)
                }
            }
        }
        
        // 2. Quét tầng 1 của thư mục Home
        if let homeFiles = try? fileManager.contentsOfDirectory(at: home, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey], options: [.skipsHiddenFiles]) {
            for f in homeFiles {
                let ext = f.pathExtension.lowercased()
                if targetExtensions.contains(ext) {
                    let fPath = f.resolvingSymlinksInPath().path
                    if !initialFiles.contains(fPath) && !fPath.contains(".SlideLock_Cache") {
                        self.lockAndCorruptIllegalSaveAs(at: f)
                    }
                }
            }
        }
    }
    
    private func saveAndCleanup(tempPptxPath: URL, sessionDir: URL, originalName: String, sessionStartTime: Date, initialFiles: Set<String>, externalSourceURL: URL? = nil) {
        Thread.sleep(forTimeInterval: 0.3)
        self.scanAndPoisonPowerPointOpenFiles(sessionDir: sessionDir)
        self.scanAndPoisonIllegalFiles(sessionStartTime: sessionStartTime, sessionDir: sessionDir, lessonName: originalName, initialFiles: initialFiles)
        
        // Nếu phiên làm việc này mở từ một file ngoài:
        if let sourceURL = externalSourceURL {
            if FileManager.default.fileExists(atPath: tempPptxPath.path) {
                self.encryptLegitimateExternalFile(at: tempPptxPath, destinationURL: sourceURL)
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
                            set wName to ""
                            try
                                set wName to (name of w) as string
                            end try
                            
                            -- 1. XỬ LÝ POPUP CẢNH BÁO FONT "Save with Fonts" / "Lưu không có phông chữ"
                            -- Tự động click "Don't Save" / "Save Without Fonts" / "Không lưu"
                            -- để lưu bình thường vào cache và triệt tiêu popup, không cho popup mở Save As
                            if wName contains "Save with Fonts" or wName contains "Fonts" or wName contains "Phông" then
                                try
                                    click button "Don't Save" of w
                                    set fontHandled to true
                                end try
                                if not fontHandled then
                                    try
                                        click button "Không lưu" of w
                                        set fontHandled to true
                                    end try
                                end if
                                if not fontHandled then
                                    try
                                        click button "Save Without Fonts" of w
                                        set fontHandled to true
                                    end try
                                end if
                                if not fontHandled then
                                    try
                                        click button 1 of w
                                        set fontHandled to true
                                    end try
                                end if
                            end if
                            
                            -- Kiểm tra trong sheet 1 của w
                            if not fontHandled then
                                try
                                    if exists (sheet 1 of w) then
                                        set theSheet to sheet 1 of w
                                        repeat with btn in (buttons of theSheet)
                                            try
                                                set btnTitle to (title of btn) as string
                                                if btnTitle is "Don't Save" or ¬
                                                   btnTitle contains "Don't Save" or ¬
                                                   btnTitle contains "Save Without Fonts" or ¬
                                                   btnTitle contains "Without Fonts" or ¬
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
                                            key code 53 -- Phím ESCape
                                        end if
                                    end if
                                end try
                            end if
                            
                            -- Kiểm tra các nút trong chính window w nếu có nút font
                            if not fontHandled then
                                try
                                    repeat with btn in (buttons of w)
                                        try
                                            set btnTitle to (title of btn) as string
                                            if btnTitle is "Don't Save" or ¬
                                               btnTitle contains "Don't Save" or ¬
                                               btnTitle contains "Save Without Fonts" or ¬
                                               btnTitle contains "Without Fonts" or ¬
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
                                    set isIllegalWin to false
                                    if wName is not missing value and wName is not "" then
                                        if wName contains "Save As" or wName contains "Save a Copy" or ¬
                                           wName contains "Lưu như" or wName contains "Lưu một bản sao" or ¬
                                           wName contains "Export" or wName contains "Xuất" or ¬
                                           wName contains "Print" or wName contains "In " or wName is "In" or ¬
                                           wName contains "Duplicate" or wName contains "Bản sao" or ¬
                                           wName contains "Nhân bản" or ¬
                                           wName contains "Move" or wName contains "Di chuyển" or ¬
                                           wName contains "Share" or wName contains "Chia sẻ" or ¬
                                           wName contains "Publish" or wName contains "Phát hành" then
                                            set isIllegalWin to true
                                        else if wName contains "Save" or wName contains "Lưu" then
                                            if not (wName contains ".pptx" or wName contains ".ppt") then
                                                set isIllegalWin to true
                                            end if
                                        end if
                                    end if
                                    
                                    -- Kiểm tra subrole AXSavePanel hoặc AXDialog
                                    if not isIllegalWin then
                                        try
                                            set sRole to (subrole of w) as string
                                            if sRole is "AXSavePanel" then
                                                set isIllegalWin to true
                                            end if
                                        end try
                                    end if
                                    
                                    -- Kiểm tra nếu cửa sổ không có tên nhưng có nút Save/Lưu hoặc Export/Xuất
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
                                            click button "Don't Save" of w
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
    
    private func scanAndKillClones(tempPptxPath: URL, sessionDir: URL, lessonDisplayName: String = "", originalName: String = "") -> Bool {
        let sessionFolderName = sessionDir.lastPathComponent
        let targetPath = tempPptxPath.path
        let targetResolvedPath = tempPptxPath.resolvingSymlinksInPath().path
        let cleanDisplayName = lessonDisplayName.replacingOccurrences(of: ".pptx", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOriginalName = originalName.replacingOccurrences(of: ".pptx", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)

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
                                        if pFullName contains ":" then
                                            set oldDelims to AppleScript's text item delimiters
                                            set AppleScript's text item delimiters to ":"
                                            set hfsParts to text items of pFullName
                                            set AppleScript's text item delimiters to oldDelims
                                            if (count of hfsParts) > 1 then
                                                set AppleScript's text item delimiters to "/"
                                                set pPosix to "/" & ((items 2 thru -1 of hfsParts) as string)
                                                set AppleScript's text item delimiters to oldDelims
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
                            -- BẮT BUỘC đường dẫn phải nằm trong sessionFolderName, .SlideLock_Cache hoặc khớp targetPath
                            if (pFullName contains "\(sessionFolderName)") or ¬
                               (pPosix contains "\(sessionFolderName)") or ¬
                               (pFullName contains ".SlideLock_Cache") or ¬
                               (pPosix contains ".SlideLock_Cache") or ¬
                               (pPosix is "\(targetPath)") or ¬
                               (pPosix is "\(targetResolvedPath)") then
                                set isOriginal to true
                                set originalOpen to true
                            else if (count of presentations) is 1 and not (pPosix contains "/Users/") and not (pPosix contains "/Volumes/") and not (pPosix contains "/tmp/") then
                                set isOriginal to true
                                set originalOpen to true
                            end if
                            
                            -- Mọi presentation khác ngoài cache bài giảng (như đã Save As ra Desktop, Documents...) đều là bản sao bất hợp pháp!
                            if not isOriginal then
                                if pPosix is not "" and not (pPosix contains "\(sessionFolderName)") and not (pPosix contains ".SlideLock_Cache") and (pPosix starts with "/") then
                                    copy pPosix to end of clones
                                else if pFullName is not "" and not (pFullName contains "\(sessionFolderName)") and not (pFullName contains ".SlideLock_Cache") then
                                    copy pFullName to end of clones
                                end if
                                
                                try
                                    close p saving no
                                end try
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
                        self.lockAndCorruptIllegalSaveAs(at: URL(fileURLWithPath: resolvedPath))
                    }
                }
                if foundClones {
                    DispatchQueue.main.async {
                        self.statusMessage = "⚠️ CẢNH BÁO BẢO MẬT: Phát hiện lưu/sao chép bài giảng! Bản sao đã bị gán mã lỗi \(self.slideLockErrorCode) và phá hủy hoàn toàn."
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
