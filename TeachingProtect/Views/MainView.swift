import SwiftUI

struct MainView: View {
    let lessons = [
        "Bài 01 - Giới thiệu",
        "Bài 02 - Nâng cao",
        "Bài 03 - Thực hành",
        "Bài 04 - Tổng kết"
    ]
    
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
    }
    
    private func openLesson(_ name: String) {
        // Implement logic: 
        // 1. Decrypt from .tp to /tmp/.../something.pptx
        // 2. PowerPointLauncher.launch(file: url)
        print("Opening \(name)...")
    }
}
