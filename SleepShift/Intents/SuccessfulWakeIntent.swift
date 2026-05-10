import AppIntents
import Foundation
import SwiftData

struct SuccessfulWakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Wake Successful"
    static let isDiscoverable = false

    @Parameter(title: "Scheduled Day") var scheduledDay: Int
    @Parameter(title: "Scheduled Wake Time") var scheduledWakeTime: Date

    init() {}
    init(scheduledDay: Int, scheduledWakeTime: Date) {
        self.scheduledDay = scheduledDay
        self.scheduledWakeTime = scheduledWakeTime
    }

    func perform() async throws -> some IntentResult {
        let container = try ModelContainer(for: ShiftProgram.self, WakeAttempt.self)
        let manager = SleepShiftManager.shared
        await manager.setup(context: container.mainContext)

        let minutesLate = Date.now.timeIntervalSince(scheduledWakeTime) / 60
        let successful = minutesLate < 15

        if successful {
            await manager.advanceDay()
        } else {
            await manager.repeatDay()
        }

        await manager.logAttempt(
            day: scheduledDay,
            scheduledTime: scheduledWakeTime,
            dismissedTime: .now,
            successful: successful
        )

        return .result()
    }
}
