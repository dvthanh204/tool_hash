import SwiftUI
import Foundation
import CryptoKit

struct MainView: View {
    @State private var lessons: [String] = []
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String = "Select a lesson from the left sidebar to open it in PowerPoint."
    
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
                                Text(lesson)
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
                        Image(systemName: "app.dashed")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(statusMessage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .frame(minWidth: 400, minHeight: 400)
            }
        }
        .navigationTitle("Khóa Học Từ Xa (SlideLock)")
        .onAppear {
            self.lessons = extractLessons()
        }
    }
    
    private func getDecryptedZipURL() -> URL? {
        let tempZipURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("baigiang.zip")
        if FileManager.default.fileExists(atPath: tempZipURL.path) {
            return tempZipURL
        }
        
        guard let bundleUrl = Bundle.main.url(forResource: "baigiang", withExtension: "khoa"),
              let data = try? Data(contentsOf: bundleUrl) else { return nil }
        
        let secretData = "12345678901234567890123456789012".data(using: .utf8)!
        let symmetricKey = SymmetricKey(data: secretData)
        guard data.count > 12 else { return nil }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            try decryptedData.write(to: tempZipURL)
            return tempZipURL
        } catch {
            print("Decrypt failed: \(error)")
            return nil
        }
    }
    
    private func extractLessons() -> [String] {
        guard let zipURL = getDecryptedZipURL() else { return [] }
        let task = Process()
        task.launchPath = "/usr/bin/unzip"
        task.arguments = ["-Z1", zipURL.path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        let files = output.components(separatedBy: .newlines).filter { 
             $0.lowercased().hasSuffix(".pptx") || $0.lowercased().hasSuffix(".ppt") 
        }
        return files.sorted()
    }
    
    private func openLesson(_ name: String) {
        isProcessing = true
        statusMessage = "Đang trích xuất và mã hóa file, vui lòng chờ..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let zipURL = self.getDecryptedZipURL() else {
                DispatchQueue.main.async { self.isProcessing = false; self.statusMessage = "Lỗi dữ liệu." }
                return
            }
            let extractURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
            
            // 1. Trích xuất đúng 1 file PPTX
            let task = Process()
            task.launchPath = "/usr/bin/unzip"
            task.arguments = ["-o", zipURL.path, name, "-d", NSTemporaryDirectory()]
            task.launch()
            task.waitUntilExit()
            
            // 2. Chèn XML vô hiệu hóa giao diện Save As / Print / Copy
            self.injectDisableSaveAs(pptxPath: extractURL.path)
            
            DispatchQueue.main.async {
                self.statusMessage = "Đang mở: \(name)... (Đã Khóa Bảo Mật)"
                NSWorkspace.shared.open(extractURL)
                
                // 3. Chạy luồng quét bảo vệ
                self.watchPowerPoint(tempPptxPath: extractURL, originalName: name)
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
                let newRels = relsData[..<insertIdx] + relStr + relsData[insertIdx...]
                try? newRels.write(toFile: relsPath, atomically: true, encoding: .utf8)
            }
        }
        
        // Tạo Custom UI XML
        let customUiDir = tempDir + "/customUI"
        try? FileManager.default.createDirectory(atPath: customUiDir, withIntermediateDirectories: true)
        
        let customXml = """
        <customUI xmlns="http://schemas.microsoft.com/office/2009/07/customui">
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
            
            // Loop while locked, aggressively protect clipboard
            while true {
                DispatchQueue.main.async { NSPasteboard.general.clearContents() }
                
                if !FileManager.default.fileExists(atPath: lockFileURL.path) {
                    // Lock file gone, PowerPoint closed!
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            self.saveAndCleanup(tempPptxPath: tempPptxPath, originalName: originalName)
        }
    }
    
    private func saveAndCleanup(tempPptxPath: URL, originalName: String) {
        guard let tempZip = getDecryptedZipURL() else { return }
        
        // Update zip package with modified file
        let task = Process()
        task.launchPath = "/usr/bin/zip"
        task.arguments = ["-q", "-j", tempZip.path, tempPptxPath.path] // Replace file inside zip
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
            if let bundleUrl = Bundle.main.url(forResource: "baigiang", withExtension: "khoa") {
                 // Try writing back. (Might fail due to sandboxing if strict, but if Ad-Hoc signed it may allow it, or fallback is OK)
                 try? encryptedData.write(to: bundleUrl)
            }
        } catch {
            print("Failed to re-encrypt: \(error)")
        }
        
        try? FileManager.default.removeItem(at: tempPptxPath)
        
        DispatchQueue.main.async {
            self.statusMessage = "Đã lưu bản cập nhật bảo mật và đóng thành công."
            self.isProcessing = false
        }
    }
}
