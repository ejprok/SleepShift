import Foundation
import SwiftData

@MainActor @Observable
final class SleepShiftManager {
    static let shared = SleepShiftManager()

    var isAuthorized = false
    var activeProgram: ShiftProgram?
    private(set) var activeAlarmID: String? = UserDefaults.standard.string(forKey: "sleepshift.alarmID")

    private var modelContext: ModelContext?
    private let shiftPerDay: Double = 6.5

    private init() {}

    func setup(context: ModelContext) {
        modelContext = context
        loadActiveProgram()
    }

    // MARK: - Program State

    private func loadActiveProgram() {
        let descriptor = FetchDescriptor<ShiftProgram>(predicate: #Predicate { $0.isActive })
        activeProgram = try? modelContext?.fetch(descriptor).first
    }

    func activateProgram(_ program: ShiftProgram) {
        program.isActive = true
        activeProgram = program
        try? modelContext?.save()
    }

    // MARK: - Wake Time Computation

    func wakeTime(forDay day: Int, program: ShiftProgram) -> Date {
        let shiftMinutes = shiftPerDay * Double(day - 1)
        let startComponents = Calendar.current.dateComponents([.hour, .minute], from: program.startWakeTime)
        let startMinutes = (startComponents.hour ?? 6) * 60 + (startComponents.minute ?? 0)
        let wakeMinutes = startMinutes - Int(shiftMinutes.rounded())

        var dayComponents = Calendar.current.dateComponents([.year, .month, .day], from: program.startDate)
        dayComponents.day = (dayComponents.day ?? 1) + (day - 1)
        dayComponents.hour = wakeMinutes / 60
        dayComponents.minute = wakeMinutes % 60
        dayComponents.second = 0
        return Calendar.current.date(from: dayComponents) ?? .now
    }

    // MARK: - Day Advancement

    func advanceDay() async {
        guard let program = activeProgram else { return }
        program.currentDay = min(program.currentDay + 1, program.totalDays)
        try? modelContext?.save()
        await scheduleNextAlarm(forDay: program.currentDay)
    }

    func repeatDay() async {
        guard let program = activeProgram else { return }
        await scheduleNextAlarm(forDay: program.currentDay)
    }

    // MARK: - Logging

    func logAttempt(day: Int, scheduledTime: Date, dismissedTime: Date?, successful: Bool) {
        guard let context = modelContext else { return }
        let attempt = WakeAttempt(day: day, scheduledTime: scheduledTime, program: activeProgram)
        attempt.dismissedTime = dismissedTime
        attempt.successful = successful
        context.insert(attempt)
        try? context.save()
    }

    // MARK: - Streak

    func currentStreak(attempts: [WakeAttempt]) -> Int {
        let sorted = attempts.sorted { $0.scheduledTime > $1.scheduledTime }
        var streak = 0
        for attempt in sorted {
            if attempt.successful { streak += 1 } else { break }
        }
        return streak
    }

    // MARK: - AlarmKit (Phase 3)

    func requestAuthorization() async {}
    func scheduleNextAlarm(forDay day: Int) async {}
    func handleForeground() async {}
    func observeAlarms() async {}
}
