import AppIntents

struct SkipTodayIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Today"
    static let isDiscoverable = false

    @Parameter(title: "Scheduled Day") var scheduledDay: Int

    init() {}
    init(scheduledDay: Int) {
        self.scheduledDay = scheduledDay
    }

    func perform() async throws -> some IntentResult {
        // Logic implemented in Phase 4
        return .result()
    }
}
