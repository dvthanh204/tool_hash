import SwiftUI
import Foundation
import CryptoKit

struct MainView: View {
    @State private var lessons: [String] = []
    
    var body: some View {
        NavigationView {
            List(lessons, id: \.self) { lesson in
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundColor(.blue)
                    
                    Text(lesson)
                        .font(.system(.body, design: .rounded))
                    
                    Spacer()
                    
                    Button("Open") {
                        openLesson(lesson)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 300)
            
            Text("Select a lesson from the left sidebar to open it in PowerPoint.")
                .foregroundColor(.secondary)
                .frame(minWidth: 400, minHeight: 400)
        }
        .navigationTitle("Teaching Protect Library")
        .onAppear {
            self.lessons = extractLessons()
        }
    }
    
    private func getDecryptedZipURL() -> URL? {
        let tempZipURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("baigiang.zip")
        // Chỉ giải mã nếu file chưa tồn tại (tối ưu hóa tốc độ)
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
        task.arguments = ["-Z1", zipURL.path] // Hủy nén chế độ list file name
        
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
        guard let zipURL = getDecryptedZipURL() else { return }
        let extractURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        
        // Trích xuất đúng 1 file
        let task = Process()
        task.launchPath = "/usr/bin/unzip"
        task.arguments = ["-o", zipURL.path, name, "-d", NSTemporaryDirectory()]
        task.launch()
        task.waitUntilExit()
        
        // Mở file
        NSWorkspace.shared.open(extractURL)
    }
}
