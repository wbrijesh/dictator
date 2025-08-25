//
//  DictatorApp.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import SwiftUI

@main
struct DictatorApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
