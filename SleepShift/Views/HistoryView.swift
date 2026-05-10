import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WakeAttempt.scheduledTime, order: .reverse) private var attempts: [WakeAttempt]

    var body: some View {
        Group {
            if attempts.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Wake attempts will appear here after your first alarm.")
                )
            } else {
                List {
                    ForEach(attempts) { attempt in
                        WakeAttemptRowView(attempt: attempt)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
