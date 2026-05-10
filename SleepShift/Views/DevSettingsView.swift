#if DEBUG
import SwiftUI
import SwiftData

struct DevSettingsView: View {
    @Bindable var manager: SleepShiftManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Timing") {
                    Toggle("Dev Mode", isOn: $manager.isDevMode)
                    if manager.isDevMode {
                        Stepper(
                            "Interval: \(manager.devModeIntervalMinutes) min",
                            value: $manager.devModeIntervalMinutes,
                            in: 1...60
                        )
                    }
                }

                if manager.isDevMode {
                    Section {
                        Text("Alarms will fire \(manager.devModeIntervalMinutes) min apart, all on the same day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Program") {
                    if let program = manager.activeProgram {
                        LabeledContent("Current day", value: "\(program.currentDay) of \(program.totalDays)")
                        LabeledContent("Active alarm", value: manager.activeAlarmID?.uuidString.prefix(8).description ?? "none")

                        Button("Reschedule Today's Alarm") {
                            Task { await manager.scheduleNextAlarm(forDay: program.currentDay) }
                        }

                        Button("Simulate Successful Wake") {
                            Task { await manager.advanceDay() }
                        }

                        Button("Reset Program", role: .destructive) {
                            resetProgram(program)
                        }
                    } else {
                        Text("No active program").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Dev Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func resetProgram(_ program: ShiftProgram) {
        if let id = manager.activeAlarmID {
            try? AlarmManager.shared.cancel(id: id)
        }
        program.isActive = false
        program.currentDay = 1
        try? modelContext.save()
        manager.setup(context: modelContext)
        dismiss()
    }
}
#endif
