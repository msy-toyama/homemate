//
//  ContentView.swift
//  HomeMate
//
//  Created by 小林将也 on 2026/06/27.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environment(AppState())
}
