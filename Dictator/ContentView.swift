//
//  ContentView.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        Text("Welcome to Dictator")
            .padding(64)
    }
}
