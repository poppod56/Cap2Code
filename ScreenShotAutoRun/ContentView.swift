import SwiftUI

struct ContentView: View {
    @StateObject private var importVM = ImportViewModel()
    @StateObject private var updateService = AppUpdateService.shared

    var body: some View {
        TabView {
            NavigationStack {
                ImportView(vm: importVM)
            }
            .tabItem { Label(String(localized: "Scan"), systemImage: "viewfinder") }

            NavigationStack {
                ResultsView()
            }
            .tabItem { Label(String(localized: "Results"), systemImage: "list.bullet.rectangle") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label(String(localized: "Settings"), systemImage: "gear") }
        }
        .onAppear {
            updateService.checkForUpdatesIfNeeded()
        }
        .alert(String(localized: "Update Available"), isPresented: $updateService.showUpdateAlert) {
            Button(String(localized: "Update")) {
                updateService.openAppStore()
            }
            Button(String(localized: "Later"), role: .cancel) { }
        } message: {
            if let info = updateService.updateInfo {
                Text(String(localized: "A new version (\(info.latestVersion)) is available. You are currently using version \(info.currentVersion)."))
            }
        }
    }
}

#Preview {
    ContentView()
}
