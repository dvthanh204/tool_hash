import SwiftUI
import Foundation
import CryptoKit

struct MainView: View {
    struct LessonInfo: Hashable {
        let safeName: String
        let displayName: String
    }
    
    @State private var lessons: [LessonInfo] = []
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String = "Đang tải dữ liệu..."
    @State private var customDataURL: URL? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    Text("DANH SÁCH BÀI GIẢNG")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
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
                        ProgressView()
                            .scaleEffect(1.5)
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
        .navigationTitle("Khóa Học Từ Xa (SlideLock)")
        .onAppear {
            self.loadLessons()
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
        let tempZipURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("baigiang.zip")
        if FileManager.default.fileExists(atPath: tempZipURL.path) {
            return tempZipURL
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
            try decryptedData.write(to: tempZipURL)
            return tempZipURL
        } catch {
            print("Decrypt failed: \(error)")
            throw AppError.decryptFailed
        }
    }
    
    private func loadLessons() {
        do {
            let zipURL = try getDecryptedZipURL()
            
            // Re-validate against the ban list to prevent App Translocation bypass!
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
                // Sắp xếp the key safeName e.g., lesson_0.pptx, lesson_1.pptx
                let sortedKeys = json.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                for safeName in sortedKeys {
                    if let displayName = json[safeName] {
                        loadedLessons.append(LessonInfo(safeName: safeName, displayName: displayName))
                    }
                }
            } else {
                // Fallback nếu manifest.json bị lỗi, đọc lại kiểu cũ unzip -Z1 (cho thẻ cũ chưa kịp tạo manifest)
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
        isProcessing = true
        statusMessage = "Đang trích xuất và mã hóa file, vui lòng chờ..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let zipURL = try? self.getDecryptedZipURL() else {
                DispatchQueue.main.async { self.isProcessing = false; self.statusMessage = "Lỗi xác thực dữ liệu nguồn." }
                return
            }
            
            // Xử lý extract theo safeName, dùng UUID để giấu đường dẫn và Set quyền execute-only (chống Finder mở)
            let secureTemp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TeachingProtectTemp").appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: secureTemp, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes([.posixPermissions: 0o333], ofItemAtPath: secureTemp.path)
            
            let extractURL = secureTemp.appendingPathComponent(lesson.displayName)
            
            // 1. Trích xuất đúng 1 file PPTX
            let task = Process()
            task.launchPath = "/usr/bin/unzip"
            task.arguments = ["-p", zipURL.path, lesson.safeName]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            let extractedData = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            guard extractedData.count > 0 else {
                DispatchQueue.main.async { self.isProcessing = false; self.statusMessage = "Lỗi giải nén bài giảng." }
                return
            }
            
            do {
                try extractedData.write(to: extractURL)
            } catch {
                DispatchQueue.main.async { self.isProcessing = false; self.statusMessage = "Lỗi lưu cache tạm thời." }
                return
            }
            
            // 2. Chèn XML vô hiệu hóa giao diện Save As / Print / Copy
            self.injectDisableSaveAs(pptxPath: extractURL.path)
            
            DispatchQueue.main.async {
                self.statusMessage = "Đang mở: \(lesson.displayName)... (Đã Khóa Bảo Mật)"
                
                // Mở PPT ở Normal Mode bằng AppleScript và tạo tag để chặn Save As/Duplicate
                let script = """
                tell application "Microsoft PowerPoint"
                    activate
                    set thePres to open (POSIX file "\(extractURL.path)")
                    try
                        set value of document property "Category" of thePres to "SlideLockSecure"
                    end try
                end tell
                """
                if let scriptObj = NSAppleScript(source: script) {
                    scriptObj.executeAndReturnError(nil)
                } else {
                    NSWorkspace.shared.open(extractURL)
                }
                
                // 3. Chạy luồng quét bảo vệ
                self.watchPowerPoint(tempPptxPath: extractURL, originalName: lesson.safeName)
            }
        }
    }
    
    private func injectDisableSaveAs(pptxPath: String) {
        let tempDir = pptxPath + "_temp_ext"
        
        // Giải nén file PPTX (đó là zip)
        let unz = Process()
        unz.launchPath = "/usr/bin/unzip"
        unz.arguments = ["-q", "-o", pptxPath, "-d", tempDir]
        unz.launch()
        unz.waitUntilExit()
        
        // Đọc .rels file
        let relsPath = tempDir + "/_rels/.rels"
        if let relsData = try? String(contentsOfFile: relsPath, encoding: .utf8), !relsData.contains("customUI") {
            if let insertIdx = relsData.range(of: "</Relationships>", options: .backwards)?.lowerBound {
                let relStr = "<Relationship Id=\"rIdCustomUI\" Type=\"http://schemas.microsoft.com/office/2007/relationships/ui/extensibility\" Target=\"customUI/customUI14.xml\"/>"
                let newRels = String(relsData[..<insertIdx]) + relStr + String(relsData[insertIdx...])
                try? newRels.write(toFile: relsPath, atomically: true, encoding: String.Encoding.utf8)
            }
        }
        
        // Tạo Custom UI XML
        let customUiDir = tempDir + "/customUI"
        try? FileManager.default.createDirectory(atPath: customUiDir, withIntermediateDirectories: true)
        
        let customXml = """
        <customUI xmlns="http://schemas.microsoft.com/office/2009/07/customui">
            <!-- SlideLockSecureSignature -->
            <commands>
                <command idMso="FileSaveAs" enabled="false"/>
                <command idMso="FileSaveAsPdfOrXps" enabled="false"/>
                <command idMso="FileSaveAsPicture" enabled="false"/>
                <command idMso="FileSaveACopy" enabled="false"/>
                <command idMso="FileExport" enabled="false"/>
                <command idMso="FileExportAsPdf" enabled="false"/>
                <command idMso="PublishToPdfOrXps" enabled="false"/>
                <command idMso="CreateVideo" enabled="false"/>
                <command idMso="FileExportToVideo" enabled="false"/>
                <command idMso="PackageForCd" enabled="false"/>
                <command idMso="CreateHandouts" enabled="false"/>
                <command idMso="ShareDocument" enabled="false"/>
                <command idMso="FileSendAsAttachment" enabled="false"/>
                <command idMso="FileSendAsPdf" enabled="false"/>
                <command idMso="FilePrint" enabled="false"/>
                <command idMso="FilePrintQuick" enabled="false"/>
                <command idMso="PrintPreviewAndPrint" enabled="false"/>
                <command idMso="Copy" enabled="false"/>
                <command idMso="Cut" enabled="false"/>
                <command idMso="SlideCopy" enabled="false"/>
                <command idMso="SlideCut" enabled="false"/>
                <command idMso="DuplicateSlide" enabled="false"/>
            </commands>
            <ribbon>
                <backstage>
                    <tab idMso="TabSave" visible="false"/>
                    <button idMso="FileSaveAs" visible="false"/>
                    <tab idMso="TabPrint" visible="false"/>
                    <tab idMso="TabExport" visible="false"/>
                    <tab idMso="TabShare" visible="false"/>
                    <tab idMso="TabPublish" visible="false"/>
                </backstage>
            </ribbon>
        </customUI>
        """
        try? customXml.write(toFile: customUiDir + "/customUI14.xml", atomically: true, encoding: .utf8)
        
        // Nén lại
        let zip = Process()
        zip.launchPath = "/usr/bin/zip"
        zip.currentDirectoryPath = tempDir
        zip.arguments = ["-q", "-r", pptxPath, "."]
        zip.launch()
        zip.waitUntilExit()
        
        // Cleanup tempDir
        try? FileManager.default.removeItem(atPath: tempDir)
    }
    
    private func watchPowerPoint(tempPptxPath: URL, originalName: String) {
        DispatchQueue.global(qos: .background).async {
            // Mac lock: File ~$name.pptx is created when PowerPoint edits a file natively
            let dir = tempPptxPath.deletingLastPathComponent()
            let lockFileName = "~$" + tempPptxPath.lastPathComponent
            let lockFileURL = dir.appendingPathComponent(lockFileName)
            
            // Wait max 30s for lock file to appear
            var isLocked = false
            for _ in 0..<300 {
                if FileManager.default.fileExists(atPath: lockFileURL.path) {
                    isLocked = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            if !isLocked {
                self.saveAndCleanup(tempPptxPath: tempPptxPath, originalName: originalName)
                return
            }
            
            // Script phát hiện và tự tiêu hủy file nếu bị Save As hoặc Duplicate ra chỗ khác!
            var loopIndex = 0
            while true {
                // Hủy bộ nhớ đệm (Clipboard) hoàn toàn
                DispatchQueue.main.async { 
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString("", forType: .string)
                }
                
                // Cứ 1 giây (10 vòng) kích hoạt AppleScript Quét tìm file Clone
                if loopIndex % 10 == 0 {
                    self.scanAndKillClones(tempPptxPath: tempPptxPath)
                }
                
                if !FileManager.default.fileExists(atPath: lockFileURL.path) {
                    // Quét nốt 1 lần cuối ngay khi file chính vừa đóng/Save As
                    self.scanAndKillClones(tempPptxPath: tempPptxPath)
                    break
                }

                
                Thread.sleep(forTimeInterval: 0.1)
                loopIndex += 1
            }
            
            self.saveAndCleanup(tempPptxPath: tempPptxPath, originalName: originalName)
        }
    }
    
    private func saveAndCleanup(tempPptxPath: URL, originalName: String) {
        guard let tempZip = try? getDecryptedZipURL() else { return }
        
        let renamedPptx = tempPptxPath.deletingLastPathComponent().appendingPathComponent(originalName)
        try? FileManager.default.moveItem(at: tempPptxPath, to: renamedPptx)
        
        // Update zip package with modified file
        let task = Process()
        task.launchPath = "/usr/bin/zip"
        task.arguments = ["-q", "-j", tempZip.path, renamedPptx.path] // Replace file inside zip
        task.launch()
        task.waitUntilExit()
        
        // Re-Encrypt and write back to final bundle!
        do {
            let zipData = try Data(contentsOf: tempZip)
            
            let secretData = "12345678901234567890123456789012".data(using: .utf8)!
            let symmetricKey = SymmetricKey(data: secretData)
            let nonce = AES.GCM.Nonce()
            
            let sealedBox = try AES.GCM.seal(zipData, using: symmetricKey, nonce: nonce)
            let encryptedData = sealedBox.combined!
            
            // Tìm URL của file baigiang.khoa thật! 
            let outsideUrl = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("baigiang.khoa")
            let insideUrl = Bundle.main.url(forResource: "baigiang", withExtension: "khoa")
            
            let targetUrl: URL?
            if FileManager.default.fileExists(atPath: outsideUrl.path) {
                targetUrl = outsideUrl
            } else {
                targetUrl = insideUrl
            }
            
            if let targetUrl = targetUrl {
                 // Try writing back. (Might fail due to sandboxing if strict, but if Ad-Hoc signed it may allow it, or fallback is OK)
                 try? encryptedData.write(to: targetUrl)
            }
        } catch {
            print("Failed to re-encrypt: \(error)")
        }
        
        try? FileManager.default.removeItem(at: renamedPptx)
        try? FileManager.default.removeItem(at: tempPptxPath) // Just in case move failed
        
        DispatchQueue.main.async {
            self.statusMessage = "Đã lưu bản cập nhật bảo mật và đóng thành công."
            self.isProcessing = false
        }
    }
    
    private func scanAndKillClones(tempPptxPath: URL) {
        let appleScriptGetAllPaths = """
        set outStr to ""
        tell application "Microsoft PowerPoint"
            try
                set allP to presentations
                repeat with p in allP
                    try
                        set tmpName to (full name of p) as string
                        if tmpName is not "" then
                            set pPath to tmpName
                            if tmpName starts with "/" or tmpName starts with "~" then
                                set pPath to tmpName
                            else
                                try
                                    set pPath to POSIX path of (tmpName as alias)
                                end try
                            end if
                            set outStr to outStr & pPath & "|"
                        end if
                    end try
                end repeat
            end try
        end tell
        return outStr
        """
        
        if let scriptObj = NSAppleScript(source: appleScriptGetAllPaths) {
            var errorInfo: NSDictionary?
            if let output = scriptObj.executeAndReturnError(&errorInfo).stringValue, !output.isEmpty {
                let openPaths = output.split(separator: "|")
                for pathSub in openPaths {
                    let pathStr = String(pathSub).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !pathStr.isEmpty && pathStr != tempPptxPath.path && FileManager.default.fileExists(atPath: pathStr) {
                        // Check if file is a locked copy containing our signature
                        let checkTask = Process()
                        checkTask.launchPath = "/usr/bin/unzip"
                        checkTask.arguments = ["-p", pathStr, "customUI/customUI14.xml"]
                        let checkPipe = Pipe()
                        checkTask.standardOutput = checkPipe
                        checkTask.launch()
                        let checkData = checkPipe.fileHandleForReading.readDataToEndOfFile()
                        
                        // Xử lý timeout ngắn hoặc zip exit
                        DispatchQueue.global().async {
                            checkTask.waitUntilExit()
                        }
                        
                        if let xmlStr = String(data: checkData, encoding: .utf8), xmlStr.contains("SlideLockSecureSignature") {
                            // Close via AppleScript completely by path
                            let closeScript = \"\"\"
                            tell application "Microsoft PowerPoint"
                                try
                                    repeat with p in presentations
                                        try
                                            set tmpName to (full name of p) as string
                                            set pPath to tmpName
                                            if tmpName starts with "/" or tmpName starts with "~" then
                                                set pPath to tmpName
                                            else
                                                try
                                                    set pPath to POSIX path of (tmpName as alias)
                                                end try
                                            end if
                                            
                                            if pPath is "\(pathStr)" then
                                                close p saving no
                                            end if
                                        end try
                                    end repeat
                                end try
                            end tell
                            \"\"\"
                            NSAppleScript(source: closeScript)?.executeAndReturnError(nil)
                            
                            // Delete illegal clone
                            try? FileManager.default.removeItem(atPath: pathStr)
                        }
                    }
                }
            }
        }
    }
}
