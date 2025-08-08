//
//  ContentView.swift
//  ScreenShotAutoRun
//
//  Created by poppod on 8/8/2568 BE.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var importVM = ImportViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                ImportView(vm: importVM)
            }
            .tabItem { Label("Import", systemImage: "square.and.arrow.down") }

            NavigationStack {
                ResultsView()
            }
            .tabItem { Label("Results", systemImage: "list.bullet.rectangle") }
        }
    }
}


#Preview {
    ContentView()
}
