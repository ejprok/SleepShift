import SwiftUI

struct WakeAttemptRowView: View {
    let attempt: WakeAttempt

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attempt.successful ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(attempt.successful ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(attempt.day)")
                    .font(.subheadline.weight(.medium))
                Text(attempt.scheduledTime, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let dismissed = attempt.dismissedTime {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Dismissed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(dismissed, style: .time)
                        .font(.caption.weight(.medium))
                }
            } else {
                Text("Skipped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
