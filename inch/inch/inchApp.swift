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
    let notificationDelegate = ForegroundNotificationDelegate()

    init() {
        do {
            container = try ModelContainerFactory.makeContainer()
        } catch {
            // Schema incompatibility from a beta build with a different schema fingerprint.
            // Wipe the store and start fresh rather than crash.
            ModelContainerFactory.deleteStore()
            do {
                container = try ModelContainerFactory.makeContainer()
            } catch {
                fatalError("Failed to create ModelContainer even after store reset: \(error)")
            }
        }

        UNUserNotificationCenter.current().delegate = notificationDelegate
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
                        group.addTask {
                            let context = ModelContext(self.container)
                            try? ExerciseDataLoader().syncFromBundle(context: context)
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
