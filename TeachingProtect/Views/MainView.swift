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
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String = "Đang tải dữ liệu..."
    @State private var customDataURL: URL? = nil
    @State private var hasAccessibilityPermission: Bool = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    if !hasAccessibilityPermission {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 18))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Yêu cầu quyền Trợ Năng (Accessibility)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("SlideLock cần quyền Trợ Năng để kích hoạt lá chắn bảo mật bài giảng (chống Save As / Copy).")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: { openAccessibilitySettings() }) {
                                    Text("Cấp Quyền")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                    }
                    
                    Text("DANH SÁCH BÀI GIẢNG")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                    
                    List(lessons, id: \.self) { lesson in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "play.rectangle.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lesson.displayName)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("Bài giảng PowerPoint bảo mật")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { openLesson(lesson) }) {
                                Text("Học Bài")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(isProcessing ? Color.gray.opacity(0.3) : Color.blue.opacity(0.15))
                                    .foregroundColor(isProcessing ? .gray : .blue)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                            .disabled(isProcessing)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                    .listStyle(.plain)
                    
                    if lessons.isEmpty {
                        VStack(spacing: 12) {
                            Text("Chưa tải được dữ liệu bài giảng.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                selectCustomDataFile()
                            }) {
                                Text("Chọn file baigiang.khoa")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                    }
                }
            }
            .frame(minWidth: 350)
            
            ZStack {
                Color(NSColor.controlBackgroundColor).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    if isProcessing {
                        Text("⏳")
                            .font(.system(size: 32))
                            .padding(.bottom, 10)
                        Text(statusMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: lessons.isEmpty ? "exclamationmark.triangle" : "app.dashed")
                            .font(.system(size: 50))
                            .foregroundColor(lessons.isEmpty ? .orange : .secondary.opacity(0.5))
                        Text(statusMessage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(lessons.isEmpty ? .red : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .frame(minWidth: 400, minHeight: 400)
            }
        }
        .onAppear {
            self.checkAccessibility()
            self.loadLessons()
            
            NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                self.checkAccessibility()
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
            revTask.launchPath = "/usr/bin/unzip"
            revTask.arguments = ["-p", zipURL.path, "revocations.json"]
            let revPipe = Pipe()
            revTask.standardOutput = revPipe
            revTask.launch()
            let revData = revPipe.fileHandleForReading.readDataToEndOfFile()
            revTask.waitUntilExit()
            if let revJson = try? JSONSerialization.jsonObject(with: revData) as? [String: Int], revJson[MachineID.current] != nil {
                self.lessons = []
                self.statusMessage = "Máy này đã bị cấm khỏi hệ thống học tập!"
                return
            }
            
            let task = Process()
            task.launchPath = "/usr/bin/unzip"
            task.arguments = ["-p", zipURL.path, "manifest.json"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            
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
                task2.launchPath = "/usr/bin/unzip"
                task2.arguments = ["-Z1", zipURL.path]
                
                let pipe2 = Pipe()
                task2.standardOutput = pipe2
                task2.launch()
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
            let extractURL = sessionFolder.appendingPathComponent(lesson.displayName)
            
            // Trích xuất file bài giảng
            let task = Process()
            task.launchPath = "/usr/bin/unzip"
            task.arguments = ["-p", zipURL.path, lesson.safeName]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
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
        unz.launchPath = "/usr/bin/unzip"
        unz.arguments = ["-q", "-o", pptxPath, "-d", tempDir]
        unz.launch()
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
    </commands>
    <ribbon>
        <backstage>
            <tab idMso="TabSave" visible="false"/>
            <tab idMso="TabPrint" visible="false"/>
            <tab idMso="TabExport" visible="false"/>
            <tab idMso="TabShare" visible="false"/>
            <tab idMso="TabPublish" visible="false"/>
        </backstage>
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
        zip.launchPath = "/usr/bin/zip"
        zip.currentDirectoryPath = tempDir
        zip.arguments = ["-q", "-r", pptxPath, "."]
        zip.launch()
        zip.waitUntilExit()
        
        try? FileManager.default.removeItem(atPath: tempDir)
    }
    
    private func watchPowerPoint(tempPptxPath: URL, sessionDir: URL, originalName: String, sessionStartTime: Date, initialFiles: Set<String>) {
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
                                        set pPath to POSIX path of tmpName
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
                self.saveAndCleanup(tempPptxPath: tempPptxPath, sessionDir: sessionDir, originalName: originalName, sessionStartTime: sessionStartTime, initialFiles: initialFiles)
                return
            }
            
            DispatchQueue.main.async {
                self.statusMessage = "Bài giảng đang mở trong chế độ bảo mật. Bạn có thể xem và chỉnh sửa bài giảng."
            }
            
            var loopIndex = 0
            var stillOpen = true
            while stillOpen {
                self.closeIllegalWindows()
                
                // 1. Quét diệt presentation clone và đầu độc file bị Save As mỗi 200ms (2 vòng lặp)
                if loopIndex % 2 == 0 {
                    stillOpen = self.scanAndKillClones(tempPptxPath: tempPptxPath, sessionDir: sessionDir)
                }
                
                // 2. Quét file descriptor ở cấp Kernel (lsof) để đầu độc mọi file PPTX/PDF PowerPoint đang mở ngoài cache mỗi 200ms (2 vòng lặp)
                if loopIndex % 2 == 1 {
                    self.scanAndPoisonPowerPointOpenFiles(sessionDir: sessionDir)
                }
                
                // 3. Quét toàn bộ hệ thống file so sánh với snapshot ban đầu để đầu độc các file mới tạo mỗi 300ms (3 vòng lặp)
                if loopIndex % 3 == 0 {
                    self.scanAndPoisonIllegalFiles(sessionStartTime: sessionStartTime, sessionDir: sessionDir, lessonName: originalName, initialFiles: initialFiles)
                }
                
                // 4. Dọn dẹp clipboard nếu chứa đối tượng slide PowerPoint mỗi 500ms (5 vòng lặp)
                if loopIndex % 5 == 0 {
                    self.sanitizeClipboard()
                }
                
                if !stillOpen {
                    break
                }
                
                Thread.sleep(forTimeInterval: 0.1)
                loopIndex += 1
            }
            
            // Quét và đầu độc lần cuối trước khi dọn dẹp
            self.scanAndPoisonPowerPointOpenFiles(sessionDir: sessionDir)
            self.scanAndPoisonIllegalFiles(sessionStartTime: sessionStartTime, sessionDir: sessionDir, lessonName: originalName, initialFiles: initialFiles)
            self.saveAndCleanup(tempPptxPath: tempPptxPath, sessionDir: sessionDir, originalName: originalName, sessionStartTime: sessionStartTime, initialFiles: initialFiles)
        }
    }
    
    private func snapshotExistingFiles() -> Set<String> {
        var existing = Set<String>()
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let scanDirs: [URL] = [
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .musicDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first,
            home,
            home.appendingPathComponent("Public"),
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/Documents"),
            URL(fileURLWithPath: "/tmp")
        ].compactMap { $0 }
        
        let targetExts: Set<String> = ["pptx", "ppt", "pptm", "ppsx", "pdf", "key", "odp"]
        for base in scanDirs {
            guard let enumerator = fileManager.enumerator(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            while let fileURL = enumerator.nextObject() as? URL {
                if enumerator.level > 3 {
                    enumerator.skipDescendants()
                    continue
                }
                if targetExts.contains(fileURL.pathExtension.lowercased()) {
                    existing.insert(fileURL.resolvingSymlinksInPath().path)
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
        process.launchPath = "/usr/sbin/lsof"
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
        let cachePath = SecureStorage.cacheDirectory.path
        
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            guard line.starts(with: "n") else { continue }
            let rawPath = String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawPath.isEmpty else { continue }
            
            if rawPath.contains(sessionPath) || rawPath.contains(cachePath) ||
               rawPath.contains("/Applications/") || rawPath.contains("/System/") ||
               rawPath.contains("/Library/Fonts/") || rawPath.contains("/usr/") ||
               rawPath.contains("/dev/") {
                continue
            }
            
            let fileURL = URL(fileURLWithPath: rawPath)
            let ext = fileURL.pathExtension.lowercased()
            
            if targetExts.contains(ext) {
                self.poisonFile(at: fileURL)
            }
        }
    }
    
    private func poisonFile(at fileURL: URL) {
        let path = fileURL.path
        // Tuyệt đối không đầu độc các file bên trong thư mục cache bảo mật của SlideLock!
        guard !path.contains(".SlideLock_Cache") else { return }
        guard FileManager.default.fileExists(atPath: path) else { return }
        
        do {
            // Lấy dung lượng file gốc để tạo file hỏng có dung lượng tương tự (tránh bị nghi ngờ file rỗng 0KB)
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            let origSize = (attrs?[.size] as? Int) ?? 128 * 1024
            let poisonSize = max(origSize, 64 * 1024)
            
            var corruptedData = Data()
            // Magic bytes bị phá hủy + Header giả mạo khiến toàn bộ parser của Office/Zip báo lỗi hỏng định dạng
            let header = "PK\u{00}\u{00}\u{FF}\u{FF}ERROR_SLIDELOCK_DEVICE_MISMATCH_CORRUPTED_STREAM_\(UUID().uuidString)\r\n"
            if let headerData = header.data(using: .utf8) {
                corruptedData.append(headerData)
            } else {
                corruptedData.append(contentsOf: [0x50, 0x4B, 0x00, 0x00, 0xFF, 0xFF])
            }
            
            // Bơm byte ngẫu nhiên chất lượng cao để phá hủy toàn bộ Central Directory và CRC32
            let fillerCount = min(poisonSize, 512 * 1024)
            var randomBytes = [UInt8](repeating: 0, count: fillerCount)
            _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            corruptedData.append(Data(randomBytes))
            
            // Thử ghi đè trực tiếp qua FileHandle để phá hủy inode ngay cả khi PowerPoint đang giữ file handle
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.truncateFile(atOffset: 0)
                handle.write(corruptedData)
                try? handle.synchronize()
                try? handle.close()
            } else {
                try corruptedData.write(to: fileURL, options: .atomic)
            }
            
            // Khóa quyền để không thể chỉnh sửa hay phục hồi
            try? FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: path)
            
            AppLogger.writeLog("Poisoned unauthorized file with corrupted format at: \(path)")
        } catch {
            AppLogger.writeLog("Failed to write poison data to \(path): \(error). Deleting file as fallback.")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private func sanitizeClipboard() {
        let pb = NSPasteboard.general
        guard let types = pb.types else { return }
        for t in types {
            let raw = t.rawValue.lowercased()
            if raw.contains("powerpoint.slide") || raw.contains("powerpoint.presentation") || raw.contains("slide-package") {
                pb.clearContents()
                AppLogger.writeLog("Sanitized clipboard containing whole slide data")
                break
            }
        }
    }
    
    private func scanAndPoisonIllegalFiles(sessionStartTime: Date, sessionDir: URL, lessonName: String, initialFiles: Set<String>) {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        var baseDirs: [URL] = [
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .musicDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first,
            home,
            home.appendingPathComponent("Public"),
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/Library/Preferences/AutoRecovery"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/tmp"),
            home.appendingPathComponent("Library/Containers/com.microsoft.Powerpoint/Data/Documents"),
            URL(fileURLWithPath: "/tmp")
        ].compactMap { $0 }
        
        if let volumes = try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for v in volumes {
                baseDirs.append(v)
            }
        }
        
        let targetExtensions: Set<String> = ["pptx", "ppt", "pptm", "ppsx", "pdf", "key", "odp"]
        let sessionPath = sessionDir.path
        let cachePath = SecureStorage.cacheDirectory.path
        let cleanLessonName = lessonName.replacingOccurrences(of: ".pptx", with: "", options: .caseInsensitive).lowercased()
        
        for dir in baseDirs {
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            while let file = enumerator.nextObject() as? URL {
                if enumerator.level > 3 {
                    enumerator.skipDescendants()
                    continue
                }
                
                let ext = file.pathExtension.lowercased()
                guard targetExtensions.contains(ext) else { continue }
                
                let filePath = file.resolvingSymlinksInPath().path
                if filePath.contains(sessionPath) || filePath.contains(cachePath) {
                    continue
                }
                
                var shouldPoison = false
                
                // 1. Nếu file không hề tồn tại trong snapshot trước khi mở bài -> 100% file vừa mới được Save As ra!
                if !initialFiles.contains(filePath) {
                    shouldPoison = true
                }
                
                // 2. Nếu file có thời gian chỉnh sửa mới (trong vòng từ lúc mở bài đến nay, dung sai 60 giây)
                if !shouldPoison {
                    if let resourceValues = try? file.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]),
                       let modDate = resourceValues.contentModificationDate ?? resourceValues.creationDate {
                        if modDate >= sessionStartTime.addingTimeInterval(-60.0) {
                            shouldPoison = true
                        }
                    }
                }
                
                // 3. Nếu tên file trùng hoặc chứa tên bài giảng đang học và nằm ngoài cache
                if !shouldPoison && !cleanLessonName.isEmpty {
                    let fileName = file.deletingPathExtension().lastPathComponent.lowercased()
                    if fileName.contains(cleanLessonName) || cleanLessonName.contains(fileName) {
                        shouldPoison = true
                    }
                }
                
                if shouldPoison {
                    self.poisonFile(at: file)
                }
            }
        }
    }
    
    private func saveAndCleanup(tempPptxPath: URL, sessionDir: URL, originalName: String, sessionStartTime: Date, initialFiles: Set<String>) {
        Thread.sleep(forTimeInterval: 0.3)
        self.scanAndPoisonPowerPointOpenFiles(sessionDir: sessionDir)
        self.scanAndPoisonIllegalFiles(sessionStartTime: sessionStartTime, sessionDir: sessionDir, lessonName: originalName, initialFiles: initialFiles)
        
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
                task.launchPath = "/usr/bin/zip"
                task.currentDirectoryPath = sessionDir.path
                task.arguments = ["-q", "-u", tempZip.path, originalName]
                task.launch()
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
                            -- 0. XỬ LÝ POPUP CẢNH BÁO FONT (khi bấm Lưu / Save As trên MacBook đời mới)
                            -- Tự động click "Save Without Fonts" / "Lưu không có phông chữ"
                            -- để lưu bình thường vào cache và triệt tiêu popup, không cho popup chặn tiến trình
                            set fontHandled to false
                            
                            -- Kiểm tra trong sheet 1 của w
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
                                        set cancelled to false
                                        try
                                            click button "Cancel" of theSheet
                                            set cancelled to true
                                        end try
                                        if not cancelled then
                                            try
                                                click button "Hủy" of theSheet
                                                set cancelled to true
                                            end try
                                        end if
                                        if not cancelled then
                                            try
                                                click button "Don't Save" of theSheet
                                                set cancelled to true
                                            end try
                                        end if
                                        delay 0.02
                                        try
                                            tell frontApp to key code 53 -- Phím ESCape
                                        end try
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
                                        delay 0.02
                                        try
                                            tell frontApp to key code 53 -- Phím ESCape
                                        end try
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
                            
                            set pPath to pFullName
                            if not (pFullName starts with "/" or pFullName starts with "~") then
                                try
                                    set pPath to POSIX path of pFullName
                                end try
                            end if
                            
                            -- Nhận diện presentation bài giảng chính xác:
                            -- BẮT BUỘC đường dẫn phải nằm trong sessionFolderName hoặc khớp chính xác targetPath!
                            if (pFullName contains "\(sessionFolderName)") or ¬
                               (pPath contains "\(sessionFolderName)") or ¬
                               (pPath is "\(targetPath)") or ¬
                               (pPath is "\(targetResolvedPath)") then
                                set isOriginal to true
                                set originalOpen to true
                            end if
                            
                            -- Mọi presentation khác không phải bài giảng gốc đều bị đóng không lưu ngay lập tức
                            if not isOriginal then
                                try
                                    close p saving no
                                end try
                                if pPath is not "" and not (pPath contains "\(sessionFolderName)") then
                                    copy pPath to end of clones
                                else if pFullName is not "" and not (pFullName contains "\(sessionFolderName)") then
                                    copy pFullName to end of clones
                                end if
                            end if
                        end repeat
                    end try
                    
                    set output to ""
                    if originalOpen then 
                        set output to "OPEN:"
                    else
                        set output to "CLOSED:"
                    end if
                    
                    repeat with c in clones
                        set output to output & c & "|"
                    end repeat
                    return output
                end tell
            end timeout
        on error errMsg number errNum
            return "ERROR:" & errMsg & ":" & errNum
        end try
        """
        
        var shouldContinue = false
        var errorInfo: NSDictionary?
        if let output = NSAppleScript(source: protectScript)?.executeAndReturnError(&errorInfo).stringValue {
            if output.starts(with: "ERROR:") {
                AppLogger.writeLog("AppleScript Exception in scanAndKillClones: \(output)")
                return true
            }
            
            let parts = output.components(separatedBy: ":")
            if parts.count >= 2 {
                let status = parts[0]
                shouldContinue = (status == "OPEN")
                
                let paths = parts[1].components(separatedBy: "|")
                for path in paths {
                    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        self.poisonFile(at: URL(fileURLWithPath: trimmed))
                    }
                }
            }
        }
        return shouldContinue
    }
}
