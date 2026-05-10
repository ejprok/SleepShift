import Foundation
import SwiftData
import SwiftUI
import AlarmKit

@MainActor @Observable
final class SleepShiftManager {
    static let shared = SleepShiftManager()

    var isAuthorized = false
    var activeProgram: ShiftProgram?
    private(set) var activeAlarmID: UUID? = {
        guard let s = UserDefaults.standard.string(forKey: "sleepshift.alarmID") else { return nil }
        return UUID(uuidString: s)
    }()

    private var modelContext: ModelContext?
    private let shiftPerDay: Double = 6.5
    private let alarmManager = AlarmManager.shared
    private let alarmIDKey = "sleepshift.alarmID"

    // MARK: - Dev Mode
    var isDevMode: Bool = UserDefaults.standard.bool(forKey: "sleepshift.devMode") {
        didSet { UserDefaults.standard.set(isDevMode, forKey: "sleepshift.devMode") }
    }
    // Interval between alarms in dev mode (minutes)
    var devModeIntervalMinutes: Int = max(1, UserDefaults.standard.integer(forKey: "sleepshift.devInterval") == 0
        ? 5 : UserDefaults.standard.integer(forKey: "sleepshift.devInterval")) {
        didSet { UserDefaults.standard.set(devModeIntervalMinutes, forKey: "sleepshift.devInterval") }
    }

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
        if isDevMode {
            // Compress entire schedule into minutes: each day fires devModeIntervalMinutes apart
            return program.startDate.addingTimeInterval(Double(day - 1) * Double(devModeIntervalMinutes) * 60)
        }

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
        guard alarmManager.authorizationState == .notDetermined else {
            isAuthorized = alarmManager.authorizationState == .authorized
            return
        }
        do {
            let status = try await alarmManager.requestAuthorization()
            isAuthorized = status == .authorized
        } catch {
            isAuthorized = false
        }
    }

    func scheduleNextAlarm(forDay day: Int) async {
        guard let program = activeProgram else { return }

        // Cancel existing — only 1 active SleepShift alarm at a time
        if let id = activeAlarmID {
            try? alarmManager.cancel(id: id)
            activeAlarmID = nil
            UserDefaults.standard.removeObject(forKey: alarmIDKey)
        }

        let wakeDate = wakeTime(forDay: day, program: program)
        let alarmID = UUID()

        let alertPresentation = AlarmPresentation.Alert(
            title: "Day \(day)/\(program.totalDays) — \(timeString(wakeDate))",
            stopButton: AlarmButton(
                text: "I'm up ✓",
                textColor: .white,
                systemImageName: "sun.max.fill"
            ),
            secondaryButton: AlarmButton(
                text: "Not today",
                textColor: .white,
                systemImageName: "moon.fill"
            )
        )

        let attributes = AlarmAttributes<WakeShiftMetadata>(
            presentation: AlarmPresentation(alert: alertPresentation),
            tintColor: .indigo
        )

        let configuration = AlarmManager.AlarmConfiguration<WakeShiftMetadata>(
            schedule: Alarm.Schedule.fixed(wakeDate),
            attributes: attributes,
            secondaryIntent: SkipTodayIntent(scheduledDay: day)
        )

        do {
            try await alarmManager.schedule(id: alarmID, configuration: configuration)
            activeAlarmID = alarmID
            UserDefaults.standard.set(alarmID.uuidString, forKey: alarmIDKey)
            UserDefaults.standard.set(day, forKey: "sleepshift.alarmDay")
            UserDefaults.standard.set(wakeDate, forKey: "sleepshift.alarmTime")
        } catch {
            // Scheduling failed — fallback button in HomeView will surface this
        }
    }

    func handleForeground() async {
        guard let program = activeProgram, program.isActive, let id = activeAlarmID else { return }
        let alarms = try? await alarmManager.alarms
        if !(alarms?.contains(where: { $0.id == id }) ?? false) {
            activeAlarmID = nil
            await scheduleNextAlarm(forDay: program.currentDay)
        }
    }

    func observeAlarms() async {
        for await alarms in alarmManager.alarmUpdates {
            guard let id = activeAlarmID else { continue }
            if !alarms.contains(where: { $0.id == id }) {
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
