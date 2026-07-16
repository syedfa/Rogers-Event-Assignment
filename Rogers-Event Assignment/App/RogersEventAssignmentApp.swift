//
//  Rogers_Event_AssignmentApp.swift
//  Rogers-Event Assignment
//
//  Created by Fayyazuddin  Syed on 2026-07-15.
//

import SwiftData
import SwiftUI

@main
struct RogersEventAssignmentApp: App {
    private let dependencies = AppDependencies()

    init() {
        dependencies.backgroundRefreshScheduler.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .modelContainer(dependencies.modelContainer)
                .environment(\.imageCache, dependencies.imageCache)
                .onAppear {
                    dependencies.backgroundRefreshScheduler.scheduleNextRefresh()
                }
        }
    }
}

private struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        if dependencies.secretsProvider.ticketmasterAPIKey == nil {
            MissingAPIKeyView()
        } else {
            HomeView(
                viewModel: dependencies.makeHomeViewModel(),
                makeDetailViewModel: dependencies.makeEventDetailViewModel
            )
        }
    }
}
