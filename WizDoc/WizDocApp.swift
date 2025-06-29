//
//  WizDocApp.swift
//  WizDoc
//
//  Created by Ilya Sobol on 6/23/25.
//

import SwiftUI

@main
struct WizDocApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
    }
}
