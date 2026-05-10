# SleepShift — Build Plan

Repo: https://github.com/ejprok/SleepShift  
Xcode project: `SleepShift.xcodeproj`

---

## Phase 0 — Project Setup

**Goal:** Compiles cleanly as an empty SwiftUI iOS 26 app with no UIKit cruft.

### 0.1 Delete UIKit template files
Remove these files from the Xcode project and disk:
- `SleepShift/AppDelegate.swift`
- `SleepShift/SceneDelegate.swift`
- `SleepShift/MainCoordinator.swift`
- `SleepShift/RootViewController.swift`
- `SleepShift/ViewController.swift`
- `SleepShift/Base.lproj/LaunchScreen.storyboard`

Remove `EJComponent` from linked frameworks (if present in project.pbxproj).

### 0.2 Create SwiftUI entry point
New file: `SleepShift/SleepShiftApp.swift`

```swift
import SwiftUI
import SwiftData

@main
struct SleepShiftApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [ShiftProgram.self, WakeAttempt.self])
        }
    }
}
```

New file: `SleepShift/ContentView.swift` — placeholder `Text("SleepShift")` until routing is wired.

### 0.3 Update project settings
In `SleepShift.xcodeproj`:
- Deployment target → **iOS 26.0**
- Remove `UIMainStoryboardFile` from Info.plist if present
- Remove `UILaunchStoryboardName` or replace with launch screen config

### 0.4 Update Info.plist
Add:
```xml
<key>NSAlarmKitUsageDescription</key>
<string>SleepShift schedules your wake alarm each day to gradually shift your sleep schedule.</string>

<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
</array>
```

### 0.5 Enable capabilities in Xcode
- Signing & Capabilities → **+** → **Alarms** (AlarmKit entitlement)
- Signing & Capabilities → **+** → **Background Modes** → check **Background fetch**

**Checkpoint:** App builds and runs to a blank SwiftUI view.

---

## Phase 1 — SwiftData Models

**Goal:** Persistent models compile and ModelContainer initializes without errors.

New file: `SleepShift/Models/ShiftProgram.swift`

```swift
import SwiftData
import Foundation

@Model
class ShiftProgram {
    var startWakeTime: Date
    var targetWakeTime: Date
    var startDate: Date
    var currentDay: Int
    var isActive: Bool

    var totalDays: Int {
        let totalMinutes = Calendar.current.dateComponents([.minute], from: targetWakeTime, to: startWakeTime).minute ?? 0
        return max(1, Int(ceil(Double(abs(totalMinutes)) / 6.5)))
    }

    init(startWakeTime: Date, targetWakeTime: Date, startDate: Date = .now) {
        self.startWakeTime = startWakeTime
        self.targetWakeTime = targetWakeTime
        self.startDate = startDate
        self.currentDay = 1
        self.isActive = false
    }
}
```

New file: `SleepShift/Models/WakeAttempt.swift`

```swift
import SwiftData
import Foundation

@Model
class WakeAttempt {
    var day: Int
    var scheduledTime: Date
    var dismissedTime: Date?
    var successful: Bool
    var program: ShiftProgram?

    init(day: Int, scheduledTime: Date, program: ShiftProgram?) {
        self.day = day
        self.scheduledTime = scheduledTime
        self.successful = false
        self.program = program
    }
}
```

**Checkpoint:** Both models compile, ModelContainer in App compiles without error.

---

## Phase 2 — SleepShiftManager (no AlarmKit yet)

**Goal:** Core business logic compiles and wake time computation is correct.

New file: `SleepShift/Managers/SleepShiftManager.swift`

```swift
import SwiftUI
import SwiftData

@MainActor @Observable
final class SleepShiftManager {
    static let shared = SleepShiftManager()

    var isAuthorized = false
    var activeProgram: ShiftProgram?
    // modelContext injected after init via property or setup(context:)
    var modelContext: ModelContext?

    private let shiftPerDay: Double = 6.5  // minutes

    private init() {}

    func setup(context: ModelContext) {
        self.modelContext = context
        loadActiveProgram()
    }

    private func loadActiveProgram() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ShiftProgram>(predicate: #Predicate { $0.isActive })
        activeProgram = try? context.fetch(descriptor).first
    }

    func wakeTime(forDay day: Int, program: ShiftProgram) -> Date {
        let shiftMinutes = shiftPerDay * Double(day - 1)
        var components = Calendar.current.dateComponents([.hour, .minute], from: program.startWakeTime)
        let startMinutes = (components.hour ?? 6) * 60 + (components.minute ?? 0)
        let wakeMinutes = startMinutes - Int(shiftMinutes.rounded())
        components.hour = wakeMinutes / 60
        components.minute = wakeMinutes % 60

        var dayComponents = Calendar.current.dateComponents([.year, .month, .day], from: program.startDate)
        dayComponents.day = (dayComponents.day ?? 1) + (day - 1)
        dayComponents.hour = components.hour
        dayComponents.minute = components.minute
        dayComponents.second = 0
        return Calendar.current.date(from: dayComponents) ?? .now
    }

    func advanceDay() async {
        guard let program = activeProgram else { return }
        program.currentDay = min(program.currentDay + 1, program.totalDays)
        try? modelContext?.save()
        await scheduleNextAlarm(forDay: program.currentDay)
    }

    func repeatDay() async {
        guard let program = activeProgram else { return }
        try? modelContext?.save()
        await scheduleNextAlarm(forDay: program.currentDay)
    }

    func logAttempt(day: Int, scheduledTime: Date, dismissedTime: Date?, successful: Bool) {
        guard let context = modelContext else { return }
        let attempt = WakeAttempt(day: day, scheduledTime: scheduledTime, program: activeProgram)
        attempt.dismissedTime = dismissedTime
        attempt.successful = successful
        context.insert(attempt)
        try? context.save()
    }

    // AlarmKit methods added in Phase 3
    func requestAuthorization() async {}
    func scheduleNextAlarm(forDay day: Int) async {}
    func handleForeground() async {}
    func observeAlarms() async {}
}
```

**Checkpoint:** Manager compiles. Wire `setup(context:)` call into `SleepShiftApp` using `.onAppear` or a custom ViewModifier that reads `@Environment(\.modelContext)`.

---

## Phase 3 — AlarmKit Integration

**Goal:** Manager can schedule and cancel a real system alarm.

> **Note:** AlarmKit is iOS 26+. Requires a physical device for alarm delivery and the Alarms entitlement.

Update `SleepShiftManager.swift` — add AlarmKit:

```swift
import AlarmKit

// Add to class body:
private var alarmManager = AlarmManager.shared
var activeAlarmID: String?  // persist in UserDefaults keyed "sleepshift.alarmID"

func requestAuthorization() async {
    let status = await alarmManager.requestAuthorization()
    isAuthorized = (status == .authorized)
}

func observeAlarms() async {
    for await alarms in alarmManager.alarmUpdates {
        // sync activeAlarmID state
        let ourAlarm = alarms.first { $0.id == activeAlarmID }
        // if alarm disappeared (dismissed/snoozed), note it
    }
}

func scheduleNextAlarm(forDay day: Int) async {
    guard let program = activeProgram else { return }
    // Cancel existing
    if let id = activeAlarmID {
        try? await alarmManager.remove(alarmWithID: id)
        activeAlarmID = nil
    }
    // Build metadata
    let wakeDate = wakeTime(forDay: day, program: program)
    let metadata = WakeShiftMetadata(day: day, scheduledWakeTime: wakeDate)
    // Build alarm attributes
    let attributes = AlarmAttributes(
        title: "Day \(day)/\(program.totalDays) — \(timeString(wakeDate))",
        subtitle: "Tap 'I'm up' within 15 min to advance",
        tintColor: .indigo,
        stopButton: AlarmAttributes.Button(
            title: "I'm up ✓",
            intent: SuccessfulWakeIntent(scheduledDay: day, scheduledWakeTime: wakeDate)
        ),
        secondaryButton: AlarmAttributes.Button(
            title: "Not today",
            intent: SkipTodayIntent(scheduledDay: day)
        )
    )
    // Schedule
    let alarm = try? await alarmManager.schedule(
        .alarm(date: wakeDate, attributes: attributes),
        metadata: metadata
    )
    activeAlarmID = alarm?.id
    UserDefaults.standard.set(activeAlarmID, forKey: "sleepshift.alarmID")
}

func handleForeground() async {
    // Re-check if our alarm still exists; if not, reschedule
    guard let program = activeProgram, program.isActive else { return }
    let alarms = await alarmManager.alarms
    if !alarms.contains(where: { $0.id == activeAlarmID }) {
        await scheduleNextAlarm(forDay: program.currentDay)
    }
}

private func timeString(_ date: Date) -> String {
    date.formatted(.dateTime.hour().minute())
}
```

New file: `SleepShift/Alarms/WakeShiftMetadata.swift`:

```swift
import AlarmKit

nonisolated struct WakeShiftMetadata: AlarmMetadata {
    let day: Int
    let scheduledWakeTime: Date
}
```

**Note on `nonisolated`:** Required to satisfy `AlarmMetadata` protocol in Xcode 26 where MainActor is the default isolation. Without it, the conformance synthesizer will emit an actor-isolation error.

**Checkpoint:** App schedules an alarm on a device. Alarm appears in Control Center / Clock app.

---

## Phase 4 — AppIntents

**Goal:** Alarm stop/secondary buttons fire intents even from the lock screen.

New file: `SleepShift/Intents/SuccessfulWakeIntent.swift`:

```swift
import AppIntents
import Foundation

struct SuccessfulWakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Wake Successful"
    static let isDiscoverable = false

    @Parameter(title: "Scheduled Day") var scheduledDay: Int
    @Parameter(title: "Scheduled Wake Time") var scheduledWakeTime: Date

    init() {}
    init(scheduledDay: Int, scheduledWakeTime: Date) {
        self.scheduledDay = scheduledDay
        self.scheduledWakeTime = scheduledWakeTime
    }

    func perform() async throws -> some IntentResult {
        let minutesLate = Date.now.timeIntervalSince(scheduledWakeTime) / 60
        let successful = minutesLate < 15

        let manager = await SleepShiftManager.shared
        if successful {
            await manager.advanceDay()
        } else {
            await manager.repeatDay()
        }
        await manager.logAttempt(
            day: scheduledDay,
            scheduledTime: scheduledWakeTime,
            dismissedTime: .now,
            successful: successful
        )
        return .result()
    }
}
```

New file: `SleepShift/Intents/SkipTodayIntent.swift`:

```swift
import AppIntents

struct SkipTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip Today"
    static let isDiscoverable = false

    @Parameter(title: "Scheduled Day") var scheduledDay: Int

    init() {}
    init(scheduledDay: Int) {
        self.scheduledDay = scheduledDay
    }

    func perform() async throws -> some IntentResult {
        let manager = await SleepShiftManager.shared
        guard let program = await manager.activeProgram else { return .result() }
        let scheduledTime = await manager.wakeTime(forDay: scheduledDay, program: program)
        await manager.repeatDay()
        await manager.logAttempt(
            day: scheduledDay,
            scheduledTime: scheduledTime,
            dismissedTime: nil,
            successful: false
        )
        return .result()
    }
}
```

> **Important:** Test intent execution from a **locked device** early. AppIntents that reference `@MainActor` types must use `await` on the actor; `SleepShiftManager.shared` access is fine because it's awaited on `@MainActor`.

**Checkpoint:** Tapping the stop/secondary button in the alarm UI fires the intent (verify by checking `currentDay` increments in the app).

---

## Phase 5 — Onboarding Screen

**Goal:** User can configure and start a shift program.

New file: `SleepShift/Views/OnboardingView.swift`

Key elements:
- `DatePicker` (`.hourAndMinute`) for current wake time
- `DatePicker` (`.hourAndMinute`) for target wake time
- Computed summary label: `"\(totalDays) days · ~6.5 min/day"`
- "Start Program" button:
  1. Calls `manager.requestAuthorization()`
  2. If authorized, creates `ShiftProgram`, inserts into context, sets `isActive = true`
  3. Calls `manager.scheduleNextAlarm(forDay: 1)`
  4. Dismisses onboarding / navigates to Home

**Checkpoint:** Onboarding creates a program and schedules day 1 alarm.

---

## Phase 6 — Home Screen

**Goal:** Main screen shows program state and today's alarm.

New file: `SleepShift/Views/HomeView.swift`

Key elements:
- Large display: `"Day \(program.currentDay) of \(program.totalDays)"`
- Today's alarm time (prominent, large font)
- Tomorrow's projected time (secondary)
- Current streak — computed from recent `WakeAttempt` records (consecutive `successful == true` from most recent backward)
- Last 7 days list (`WakeAttemptRowView`)
- Fallback button "Schedule Today's Alarm" — visible when `manager.activeAlarmID` is nil or not in `alarmManager.alarms`
- `.task { await manager.observeAlarms() }` — keeps alarm state live
- `.onChange(of: scenePhase) { if phase == .active { await manager.handleForeground() } }`

**Checkpoint:** Home shows correct day, time, and streak. Fallback button schedules alarm.

---

## Phase 7 — History Screen

**Goal:** Full log of wake attempts.

New file: `SleepShift/Views/HistoryView.swift`

Key elements:
- `@Query(sort: \WakeAttempt.scheduledTime, order: .reverse)` var attempts
- List rows showing: day number, scheduled time, actual dismiss time (or "—"), success/fail badge
- Navigation accessible from Home (e.g., toolbar button)

**Checkpoint:** History shows all logged attempts in reverse chronological order.

---

## Phase 8 — App Navigation / Routing

**Goal:** Smooth flow between Onboarding → Home ↔ History.

Update `ContentView.swift`:
```swift
struct ContentView: View {
    @Query var programs: [ShiftProgram]
    @Environment(\.modelContext) var context

    var activeProgram: ShiftProgram? { programs.first(where: { $0.isActive }) }

    var body: some View {
        if activeProgram != nil {
            TabView {  // or NavigationStack with sidebar
                HomeView()
                HistoryView()
            }
        } else {
            OnboardingView()
        }
    }
}
```

---

## Phase 9 — Background Reliability

**Goal:** Alarm is always scheduled, even if app hasn't been opened.

Update `SleepShiftApp.swift` — register BGAppRefreshTask:

```swift
import BackgroundTasks

// In init() or via .backgroundTask modifier:
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.prokopik.sleepshift.refresh",
    using: nil
) { task in
    Task {
        await SleepShiftManager.shared.handleForeground()
        task.setTaskCompleted(success: true)
        // Re-schedule next background fetch
        scheduleBackgroundRefresh()
    }
}
```

Add `BGTaskSchedulerPermittedIdentifiers` to Info.plist:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.prokopik.sleepshift.refresh</string>
</array>
```

**Checkpoint:** Background refresh re-schedules alarm when app hasn't been foregrounded (test with Xcode's `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.prokopik.sleepshift.refresh"]`).

---

## Phase 10 — Polish

- Accent color: indigo (update `Assets.xcassets/AccentColor`)
- App icon: placeholder → final asset
- Haptic feedback on "Start Program" and intent completion
- Accessibility: `.accessibilityLabel` on time displays
- Empty states: Onboarding hint if no program; History empty state
- Edge cases:
  - Program completion (`currentDay == totalDays`) → show congratulations, deactivate program
  - Target already reached (same wake time) → show completion immediately
  - AlarmKit not authorized → show Settings deep-link prompt

---

## File Structure (final)

```
SleepShift/
├── SleepShiftApp.swift
├── ContentView.swift
├── Models/
│   ├── ShiftProgram.swift
│   └── WakeAttempt.swift
├── Managers/
│   └── SleepShiftManager.swift
├── Alarms/
│   └── WakeShiftMetadata.swift
├── Intents/
│   ├── SuccessfulWakeIntent.swift
│   └── SkipTodayIntent.swift
├── Views/
│   ├── OnboardingView.swift
│   ├── HomeView.swift
│   ├── HistoryView.swift
│   └── WakeAttemptRowView.swift
├── Assets.xcassets/
├── Info.plist
└── SleepShift.entitlements  ← add Alarms entitlement here
```

---

## Build Order Summary

| Phase | What | Unblocks |
|-------|------|----------|
| 0 | Project setup (SwiftUI, iOS 26, Info.plist, capabilities) | Everything |
| 1 | SwiftData models | Manager, Views |
| 2 | SleepShiftManager (no AlarmKit) | Views, logic |
| 3 | AlarmKit integration | Real alarms, Intents |
| 4 | AppIntents | Alarm button actions |
| 5 | Onboarding | Start program flow |
| 6 | Home | Daily use |
| 7 | History | Logging visibility |
| 8 | Navigation routing | Full app flow |
| 9 | Background refresh | Reliability |
| 10 | Polish | Ship |

---

## Known Constraints / Gotchas

- **AlarmKit requires physical device** — simulator does not deliver alarms
- **`nonisolated` on `WakeShiftMetadata`** — mandatory in Xcode 26 due to default MainActor isolation
- **One alarm at a time** — always cancel existing before scheduling new
- **AppIntents lock screen** — test from locked device early; intent execution context is different from foreground
- **SwiftData ModelContainer for future widget** — keep container setup in one place; don't create multiple containers
- **`alarmManager.alarmUpdates` is `AsyncSequence`** — iterate with `.task {}` in SwiftUI, not `onAppear`
