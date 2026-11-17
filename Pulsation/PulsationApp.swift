import SwiftUI

@main
struct PulsationApp: App {
    @StateObject private var viewModel = MetronomeViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
        }
    }
}
