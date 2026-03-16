import SwiftUI
import SwiftData
import BackgroundTasks
import InchShared

@main
struct InchApp: App {
    let container: ModelContainer
    let watchConnectivity = WatchConnectivityService()
    let healthKit = HealthKitService()
    let motionRecording = MotionRecordingService()
    let dataUpload = DataUploadService()
    let notificationService = NotificationService()
    let metricKit = MetricKitService()

    init() {
        do {
            container = try ModelContainerFactory.makeContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        registerBGTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environment(watchConnectivity)
                .environment(healthKit)
                .environment(motionRecording)
                .environment(dataUpload)
                .environment(notificationService)
                .task {
                    watchConnectivity.activate()
                    await notificationService.checkAuthorizationStatus()
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            let context = ModelContext(self.container)
                            await self.watchConnectivity.handleCompletionReports(context: context)
                        }
                        group.addTask {
                            let context = ModelContext(self.container)
                            await self.watchConnectivity.handleReceivedFiles(context: context)
                        }
                    }
                }
        }
    }

    // MARK: - Background Tasks

    private func registerBGTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: DataUploadService.taskIdentifier,
            using: nil
        ) { [self] task in
            guard let processingTask = task as? BGProcessingTask else { return }
            Task { @MainActor in
                let context = ModelContext(container)
                await dataUpload.handleBGUpload(task: processingTask, context: context)
            }
        }
    }
}
