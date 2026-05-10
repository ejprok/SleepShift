import Foundation
import SwiftData
import AlarmKit

@MainActor @Observable
final class SleepShiftManager {
    static let shared = SleepShiftManager()

    var isAuthorized = false
    var activeProgram: ShiftProgram?
    private(set) var activeAlarmID: String? = UserDefaults.standard.string(forKey: "sleepshift.alarmID")

    private var modelContext: ModelContext?
    private let shiftPerDay: Double = 6.5
    private let alarmManager = AlarmManager.shared
    private let alarmIDKey = "sleepshift.alarmID"

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

    // MARK: - AlarmKit

    func requestAuthorization() async {
        let status = await alarmManager.requestAuthorization()
        isAuthorized = (status == .authorized)
    }

    func scheduleNextAlarm(forDay day: Int) async {
        guard let program = activeProgram else { return }

        // Always cancel existing before scheduling — only 1 active alarm at a time
        if let id = activeAlarmID {
            try? await alarmManager.remove(alarmWithID: id)
            activeAlarmID = nil
            UserDefaults.standard.removeObject(forKey: alarmIDKey)
        }

        let wakeDate = wakeTime(forDay: day, program: program)
        let metadata = WakeShiftMetadata(day: day, scheduledWakeTime: wakeDate)

        let attributes = AlarmAttributes(
            title: "Day \(day)/\(program.totalDays) — \(timeString(wakeDate))",
            subtitle: "Tap 'I'm up' within 15 min to advance",
            tintColor: .indigo,
            stopButton: AlarmAttributes.Button(
                title: "I'm up ✓",
                intent: SuccessfulWakeIntent(scheduledDay: day, scheduledWakeTime: wakeDate)
            ),
            secondaryButton: AlarmAttributes.Button(
                title: "Not today",
                intent: SkipTodayIntent(scheduledDay: day)
            )
        )

        do {
            let alarm = try await alarmManager.schedule(
                .alarm(date: wakeDate, attributes: attributes),
                metadata: metadata
            )
            activeAlarmID = alarm.id
            UserDefaults.standard.set(alarm.id, forKey: alarmIDKey)
        } catch {
            // Alarm scheduling failed — foreground fallback button will surface this
        }
    }

    func handleForeground() async {
        guard let program = activeProgram, program.isActive else { return }
        let alarms = await alarmManager.alarms
        if !alarms.contains(where: { $0.id == activeAlarmID }) {
            activeAlarmID = nil
            await scheduleNextAlarm(forDay: program.currentDay)
        }
    }

    func observeAlarms() async {
        for await alarms in alarmManager.alarmUpdates {
            let stillActive = alarms.contains { $0.id == activeAlarmID }
            if !stillActive {
                activeAlarmID = nil
                UserDefaults.standard.removeObject(forKey: alarmIDKey)
            }
        }
    }

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}
