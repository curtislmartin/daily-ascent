import SwiftUI
import SwiftData
import BackgroundTasks
import UIKit
import OSLog
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
    let analytics = AnalyticsService()
    let communityBenchmark = CommunityBenchmarkService()

    init() {
        do {
            container = try ModelContainerFactory.makeContainer()
        } catch {
            let logger = Logger(subsystem: "dev.clmartin.inch", category: "AppInit")
            logger.critical("Failed to create ModelContainer: \(error, privacy: .public)")
            fatalError("Failed to create ModelContainer: \(error)")
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
                .environment(analytics)
                .environment(communityBenchmark)
                .task {
                    watchConnectivity.activate()
                    await notificationService.checkAuthorizationStatus()

                    let analyticsContext = ModelContext(self.container)
                    let userSettings = (try? analyticsContext.fetch(FetchDescriptor<UserSettings>()))?.first
                    analytics.configure(enabled: userSettings?.analyticsEnabled ?? false)

                    if userSettings?.isFirstLaunch == true {
                        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                        let osVersion = UIDevice.current.systemVersion
                        analytics.record(AnalyticsEvent(
                            name: "app_installed",
                            properties: .appInstalled(appVersion: appVersion, osVersion: osVersion)
                        ))
                        userSettings?.isFirstLaunch = false
                        try? analyticsContext.save()
                    }

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

                    // Lifetime benchmark sync (once per app launch; server upserts on device_hash)
                    if userSettings?.communityBenchmarksEnabled == true {
                        let syncContext = ModelContext(self.container)
                        let allSets = (try? syncContext.fetch(FetchDescriptor<CompletedSet>())) ?? []
                        let enrolments = (try? syncContext.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []

                        let totalWorkouts = Set(allSets.map { Calendar.current.startOfDay(for: $0.sessionDate) }).count
                        let totalReps = allSets.reduce(0) { $0 + $1.actualReps }
                        let enrolledCount = enrolments.filter(\.isActive).count

                        communityBenchmark.uploadLifetimeBenchmark(
                            totalWorkouts: totalWorkouts,
                            totalLifetimeReps: totalReps,
                            enrolledExerciseCount: enrolledCount
                        )
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
                if let plistURL = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
                   let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
                   let urlString = dict["SupabaseURL"] as? String,
                   let url = URL(string: urlString),
                   let anonKey = dict["SupabaseAnonKey"] as? String {
                    await analytics.flush(supabaseURL: url, anonKey: anonKey)
                }
                processingTask.setTaskCompleted(success: true)
            }
        }
    }
}
