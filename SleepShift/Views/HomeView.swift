import SwiftUI
import SwiftData

struct HomeView: View {
    var manager: SleepShiftManager
    var onShowHistory: () -> Void
    @Query(sort: \WakeAttempt.scheduledTime, order: .reverse) private var attempts: [WakeAttempt]
    @State private var scheduling = false
    #if DEBUG
    @State private var showDevSettings = false
    #endif
    private var recentAttempts: [WakeAttempt] { Array(attempts.prefix(7)) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let program = manager.activeProgram {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR MORNING, IN MOTION").font(.caption.weight(.bold)).tracking(2).foregroundStyle(ShiftStyle.accent)
                        Text("A little earlier.\nA little closer.").font(.system(.largeTitle, design: .serif).weight(.medium))
                    }
                    alarmCard(program)
                    journeyCard(program)
                    if recentAttempts.isEmpty {
                        ShiftCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("One morning at a time", systemImage: "leaf").font(.headline).foregroundStyle(ShiftStyle.accent)
                                Text("Your wake-up history will appear here after your first alarm.").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        HStack { Text("Recent mornings").font(.title3.weight(.semibold)); Spacer(); Button("See all", action: onShowHistory) }
                        ShiftCard {
                            VStack(spacing: 0) {
                                ForEach(recentAttempts) { attempt in
                                    WakeAttemptRowView(attempt: attempt)
                                    if attempt.id != recentAttempts.last?.id { Divider() }
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("No active shift", systemImage: "sunrise")
                }
            }.padding(24)
        }.background(ShiftStyle.background.ignoresSafeArea()).tint(ShiftStyle.accent)
        .navigationTitle("SleepShift").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onShowHistory) { Image(systemName: "clock.arrow.circlepath") }.accessibilityLabel("Wake-up history")
            }
            #if DEBUG
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showDevSettings = true } label: { Image(systemName: "hammer") }.accessibilityLabel("Developer settings")
            }
            #endif
        }
        .task { await manager.observeAlarms() }
        #if DEBUG
        .sheet(isPresented: $showDevSettings) { DevSettingsView(manager: manager) }
        #endif
    }
    private func alarmCard(_ program: ShiftProgram) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Planned wake-up · Step \(program.currentDay)", systemImage: "sunrise.fill").font(.subheadline.weight(.medium)).foregroundStyle(ShiftStyle.accent)
            Text(manager.wakeTime(forDay: program.currentDay, program: program), style: .time)
                .font(.system(.largeTitle, design: .rounded).weight(.light))
            Label(manager.activeAlarmID == nil ? "Alarm not scheduled" : "Alarm scheduled", systemImage: manager.activeAlarmID == nil ? "bell.slash" : "checkmark.circle.fill")
                .font(.subheadline.weight(.medium)).foregroundStyle(ShiftStyle.accent)
            #if DEBUG
            if manager.isDevMode {
                Text("Developer mode: test alarms use the short interval in developer settings.").font(.footnote).foregroundStyle(.secondary)
            }
            #endif
            if let error = manager.lastScheduleError {
                Label(error, systemImage: "exclamationmark.triangle").font(.footnote)
            }
            if manager.activeAlarmID == nil || manager.lastScheduleError != nil {
                Button {
                    scheduling = true
                    Task { await manager.scheduleNextAlarm(forDay: program.currentDay); scheduling = false }
                } label: { Text(scheduling ? "Scheduling…" : "Schedule alarm") }
                    .buttonStyle(ShiftPrimaryButton()).disabled(scheduling)
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(ShiftStyle.dawn, in: RoundedRectangle(cornerRadius: 32))
    }
    private func journeyCard(_ program: ShiftProgram) -> some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text("Your shift").font(.title3.weight(.semibold)); Spacer(); Text("\(program.currentDay) / \(program.totalDays)").foregroundStyle(.secondary) }
                ProgressView(value: Double(max(0, program.currentDay - 1)), total: Double(max(1, program.totalDays - 1)))
                    .tint(ShiftStyle.accent).accessibilityLabel("Wake-time shift progress")
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) { Text("STARTED AT").font(.caption2.weight(.bold)); Text(program.startWakeTime, style: .time).font(.headline) }
                    Spacer()
                    Image(systemName: "arrow.right").foregroundStyle(ShiftStyle.accent).accessibilityHidden(true)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) { Text("HEADING TO").font(.caption2.weight(.bold)); Text(program.targetWakeTime, style: .time).font(.headline) }
                }
                if program.currentDay < program.totalDays {
                    Divider()
                    HStack { Text("Next step").foregroundStyle(.secondary); Spacer(); Text(manager.wakeTime(forDay: program.currentDay + 1, program: program), style: .time).fontWeight(.semibold) }.font(.subheadline)
                }
                let streak = manager.currentStreak(attempts: Array(attempts))
                if streak > 0 { Label("\(streak) successful wake-ups in a row", systemImage: "sparkles").font(.footnote).foregroundStyle(ShiftStyle.accent) }
            }
        }
    }
}
