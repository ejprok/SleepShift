import SwiftUI

struct WakeAttemptRowView: View {
    let attempt: WakeAttempt
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: attempt.successful ? "sun.max" : "moon")
                .font(.title3).foregroundStyle(ShiftStyle.accent).frame(width: 40, height: 40)
                .background(ShiftStyle.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(attempt.scheduledTime, format: .dateTime.month(.abbreviated).day()).font(.headline)
                Text("Step \(attempt.day) · \(attempt.scheduledTime.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                Text(attempt.successful ? "Successful wake-up" : attempt.dismissedTime == nil ? "Skipped" : "Outside wake window").font(.caption.weight(.medium)).foregroundStyle(ShiftStyle.accent)
                if let dismissed = attempt.dismissedTime {
                    Text("Dismissed \(dismissed.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 12).accessibilityElement(children: .combine)
    }
}
