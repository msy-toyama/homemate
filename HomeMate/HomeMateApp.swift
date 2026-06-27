//
//  HomeMateApp.swift
//  HomeMate
//
//  Created by 小林将也 on 2026/06/27.
//

import SwiftUI
import CoreData

@main
struct HomeMateApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
