import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WakeAttempt.scheduledTime, order: .reverse) private var attempts: [WakeAttempt]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Every morning\nis part of the story.").font(.system(.largeTitle, design: .serif).weight(.medium))
                if attempts.isEmpty {
                    DawnIllustration()
                    Text("A fresh start").font(.title2.weight(.semibold))
                    Text("Your wake-up history will appear here after your first alarm. There’s no perfect streak to chase.").foregroundStyle(.secondary)
                } else {
                    ShiftCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(attempts.filter(\.successful).count) successful wake-ups").font(.title2.weight(.medium))
                            Text("Across \(attempts.count) recorded attempts").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    LazyVStack(spacing: 12) {
                        ForEach(attempts) { attempt in ShiftCard { WakeAttemptRowView(attempt: attempt) } }
                    }
                }
            }.padding(24)
        }.background(ShiftStyle.background.ignoresSafeArea()).tint(ShiftStyle.accent)
            .navigationTitle("Your mornings").navigationBarTitleDisplayMode(.inline)
    }
}
