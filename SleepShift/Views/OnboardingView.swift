import SwiftUI

struct OnboardingView: View {
    var onStart: (Date, Date) -> Void
    @State private var currentWakeTime = defaultTime(hour: 7, minute: 0)
    @State private var targetWakeTime = defaultTime(hour: 5, minute: 30)
    @State private var starting = false
    private var totalDays: Int {
        let minutes = abs(Calendar.current.dateComponents([.minute], from: targetWakeTime, to: currentWakeTime).minute ?? 0)
        return max(1, Int(ceil(Double(minutes) / 6.5)))
    }
    private var isValid: Bool { targetWakeTime < currentWakeTime }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("SLEEPSHIFT").font(.caption.weight(.bold)).tracking(3).foregroundStyle(ShiftStyle.accent)
                DawnIllustration()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Earlier mornings.\nSmall beginnings.").font(.system(.largeTitle, design: .serif).weight(.medium))
                    Text("Move your wake-up time a little earlier, one morning at a time.").foregroundStyle(.secondary)
                }
                ShiftCard {
                    VStack(spacing: 20) {
                        timeRow("Where you are", subtitle: "Your usual wake-up time", icon: "moon", selection: $currentWakeTime)
                        Divider()
                        timeRow("Where you’re headed", subtitle: "Your earlier wake-up time", icon: "sunrise", selection: $targetWakeTime)
                    }
                }
                if isValid {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("About \(totalDays) steps to your new morning", systemImage: "arrow.up.forward").font(.headline)
                        Text("Around 6½ minutes earlier per step. Your first alarm starts at your usual time.").font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    Label("Choose a target earlier than your usual wake-up time.", systemImage: "info.circle").font(.subheadline).foregroundStyle(ShiftStyle.accent)
                }
                Button {
                    starting = true
                    onStart(currentWakeTime, targetWakeTime)
                } label: {
                    HStack { Text(starting ? "Setting up your morning…" : "Begin my shift"); Spacer(); Image(systemName: "arrow.right") }
                }.buttonStyle(ShiftPrimaryButton()).disabled(!isValid || starting).opacity(isValid ? 1 : 0.5)
                Text("Next, allow SleepShift to schedule system alarms on your iPhone.").font(.footnote).foregroundStyle(.secondary)
            }.padding(24).padding(.bottom, 24)
        }.background(ShiftStyle.dawn.ignoresSafeArea()).tint(ShiftStyle.accent)
    }
    private func timeRow(_ title: String, subtitle: String, icon: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(ShiftStyle.accent)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute).datePickerStyle(.compact).labelsHidden()
        }
    }
}
private func defaultTime(hour: Int, minute: Int) -> Date {
    Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
}
