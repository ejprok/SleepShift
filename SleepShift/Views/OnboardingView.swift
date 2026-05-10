import SwiftUI

struct OnboardingView: View {
    var onStart: (Date, Date) -> Void

    @State private var currentWakeTime: Date = defaultTime(hour: 7, minute: 0)
    @State private var targetWakeTime: Date = defaultTime(hour: 5, minute: 30)

    private var totalDays: Int {
        let minutes = abs(
            Calendar.current.dateComponents([.minute], from: targetWakeTime, to: currentWakeTime).minute ?? 0
        )
        return max(1, Int(ceil(Double(minutes) / 6.5)))
    }

    private var isValid: Bool {
        targetWakeTime < currentWakeTime
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                header
                pickers
                summary
                startButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 48)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("SleepShift")
                .font(.largeTitle.bold())
            Text("Gradually shift your wake time,\none day at a time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var pickers: some View {
        VStack(spacing: 28) {
            pickerRow(label: "Current wake time", selection: $currentWakeTime)
            Divider()
            pickerRow(label: "Target wake time", selection: $targetWakeTime)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func pickerRow(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }

    private var summary: some View {
        Group {
            if isValid {
                Text("\(totalDays) days · ~6.5 min/day")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.indigo)
            } else {
                Text("Target must be earlier than current wake time")
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
        .multilineTextAlignment(.center)
        .animation(.easeInOut(duration: 0.2), value: isValid)
    }

    private var startButton: some View {
        Button {
            onStart(currentWakeTime, targetWakeTime)
        } label: {
            Text("Start Program")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.indigo)
        .disabled(!isValid)
    }
}

private func defaultTime(hour: Int, minute: Int) -> Date {
    Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
}
