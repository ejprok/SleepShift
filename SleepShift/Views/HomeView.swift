import SwiftUI
import SwiftData

struct HomeView: View {
    var manager: SleepShiftManager
    var onShowHistory: () -> Void

    @Query(sort: \WakeAttempt.scheduledTime, order: .reverse) private var attempts: [WakeAttempt]
    #if DEBUG
    @State private var showDevSettings = false
    #endif

    private var program: ShiftProgram? { manager.activeProgram }
    private var recentAttempts: [WakeAttempt] { Array(attempts.prefix(7)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                if let program {
                    dayCard(program: program)
                    alarmCard(program: program)
                    if !recentAttempts.isEmpty {
                        recentCard
                    }
                } else {
                    ContentUnavailableView("No Active Program", systemImage: "moon.zzz")
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("SleepShift")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("History") { onShowHistory() }
            }
            #if DEBUG
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showDevSettings = true } label: {
                    Image(systemName: "hammer")
                }
            }
            #endif
        }
        .task { await manager.observeAlarms() }
        #if DEBUG
        .sheet(isPresented: $showDevSettings) {
            DevSettingsView(manager: manager)
        }
        #endif
    }

    // MARK: - Day Card

    private func dayCard(program: ShiftProgram) -> some View {
        VStack(spacing: 6) {
            Text("Day \(program.currentDay) of \(program.totalDays)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            let streak = manager.currentStreak(attempts: Array(attempts))
            if streak > 0 {
                Label("\(streak) day streak", systemImage: "flame.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Alarm Card

    private func alarmCard(program: ShiftProgram) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Today's alarm")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(manager.wakeTime(forDay: program.currentDay, program: program), style: .time)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.indigo)
            }

            if program.currentDay < program.totalDays {
                Divider()
                HStack {
                    Text("Tomorrow")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(manager.wakeTime(forDay: program.currentDay + 1, program: program), style: .time)
                        .font(.subheadline.weight(.medium))
                }
            }

            if manager.activeAlarmID == nil {
                Divider()
                Button {
                    Task { await manager.scheduleNextAlarm(forDay: program.currentDay) }
                } label: {
                    Label("Schedule Today's Alarm", systemImage: "alarm.waves.left.and.right")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recent Attempts Card

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(recentAttempts) { attempt in
                    WakeAttemptRowView(attempt: attempt)
                    if attempt.id != recentAttempts.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
