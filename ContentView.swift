import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ShiftCalendarView()
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
                .tag(0)
            
            ScannerView()
                .tabItem {
                    Label("スキャン", systemImage: "camera")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

struct SettingsView: View {
    @AppStorage("userName") private var userName: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ユーザー情報")) {
                    TextField("あなたの名前", text: $userName)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("アプリについて")) {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}