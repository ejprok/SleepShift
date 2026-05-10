import AppIntents
import SwiftData

struct SkipTodayIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Today"
    static let isDiscoverable = false

    @Parameter(title: "Scheduled Day") var scheduledDay: Int

    init() {}
    init(scheduledDay: Int) {
        self.scheduledDay = scheduledDay
    }

    func perform() async throws -> some IntentResult {
        let container = try ModelContainer(for: ShiftProgram.self, WakeAttempt.self)
        let manager = SleepShiftManager.shared
        await manager.setup(context: container.mainContext)

        let scheduledTime: Date = await MainActor.run {
            if let program = manager.activeProgram {
                return manager.wakeTime(forDay: scheduledDay, program: program)
            }
            return UserDefaults.standard.object(forKey: "sleepshift.alarmTime") as? Date ?? .now
        }

        await manager.repeatDay()

        await manager.logAttempt(
            day: scheduledDay,
            scheduledTime: scheduledTime,
            dismissedTime: nil,
            successful: false
        )

        return .result()
    }
}
