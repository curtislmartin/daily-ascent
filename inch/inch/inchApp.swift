import SwiftUI
import SwiftData
import InchShared

@main
struct InchApp: App {
    let container: ModelContainer
    let watchConnectivity = WatchConnectivityService()

    init() {
        do {
            container = try ModelContainerFactory.makeContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environment(watchConnectivity)
                .task {
                    watchConnectivity.activate()
                    let context = ModelContext(container)
                    await watchConnectivity.handleCompletionReports(context: context)
                }
        }
    }
}
