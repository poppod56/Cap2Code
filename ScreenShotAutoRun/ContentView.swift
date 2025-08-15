import SwiftUI

struct ContentView: View {
    @StateObject private var importVM = ImportViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                ImportView(vm: importVM)
            }
            .tabItem { Label("Scan", systemImage: "viewfinder") }

            NavigationStack {
                ResultsView()
            }
            .tabItem { Label("Results", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

#Preview {
    ContentView()
}
