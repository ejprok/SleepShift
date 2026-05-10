import AlarmKit

// nonisolated required: SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor would otherwise
// prevent conformance to AlarmMetadata, which expects non-isolated access.
nonisolated struct WakeShiftMetadata: AlarmMetadata {
    let day: Int
    let scheduledWakeTime: Date
}
