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
        manager.setup(context: container.mainContext)

        let scheduledTime: Date
        if let program = manager.activeProgram {
            scheduledTime = manager.wakeTime(forDay: scheduledDay, program: program)
        } else {
            scheduledTime = UserDefaults.standard.object(forKey: "sleepshift.alarmTime") as? Date ?? .now
        }

        await manager.repeatDay()

        manager.logAttempt(
            day: scheduledDay,
            scheduledTime: scheduledTime,
            dismissedTime: nil,
            successful: false
        )

        return .result()
    }
}
