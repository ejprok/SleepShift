# SleepShift — Build Plan

Repo: https://github.com/ejprok/SleepShift  
Xcode project: `SleepShift.xcodeproj`

---

## Phase 0 — Project Setup

**Goal:** Compiles cleanly on iOS 26 with the UIKit coordinator skeleton intact.

### 0.1 Keep the UIKit coordinator structure
The template's `AppDelegate` / `SceneDelegate` / `MainCoordinator` / `RootViewController` stay. SwiftUI views will be hosted inside `UIHostingController` instances; navigation is driven entirely by the coordinator, not SwiftUI `NavigationStack` or `TabView`.

Delete only the unused stub:
- `SleepShift/ViewController.swift` (empty placeholder — replaced by real view controllers in later phases)

### 0.2 Update AppDelegate — set up SwiftData ModelContainer
`AppDelegate` owns the `ModelContainer` and exposes it as a property. Every coordinator that needs data access gets it injected.

```swift
// AppDelegate.swift
import UIKit
import SwiftData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var modelContainer: ModelContainer = {
        try! ModelContainer(for: ShiftProgram.self, WakeAttempt.self)
    }()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register BGAppRefreshTask identifier here (Phase 9)
        return true
    }
    // ... scene lifecycle unchanged
}
```

### 0.3 Update SceneDelegate — call manager setup
```swift
// SceneDelegate.swift — in scene(_:willConnectTo:)
let container = (UIApplication.shared.delegate as! AppDelegate).modelContainer
SleepShiftManager.shared.setup(context: container.mainContext)
```

### 0.4 Update project settings
In `SleepShift.xcodeproj`:
- Deployment target → **iOS 26.0**

### 0.5 Update Info.plist
Add:
```xml
<key>NSAlarmKitUsageDescription</key>
<string>SleepShift schedules your wake alarm each day to gradually shift your sleep schedule.</string>

<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
</array>
```

### 0.6 Enable capabilities in Xcode
- Signing & Capabilities → **+** → **Alarms** (AlarmKit entitlement)
- Signing & Capabilities → **+** → **Background Modes** → check **Background fetch**

**Checkpoint:** App builds and runs to the existing template root screen.

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

**Checkpoint:** Both models compile, `ModelContainer` in `AppDelegate` initializes without error.

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

**Checkpoint:** Manager compiles. `setup(context:)` is called from `SceneDelegate` after the container is ready.

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

New file: `SleepShift/Views/OnboardingView.swift` — pure SwiftUI view, no navigation logic.

Key elements:
- `DatePicker` (`.hourAndMinute`) for current wake time
- `DatePicker` (`.hourAndMinute`) for target wake time
- Computed summary label: `"\(totalDays) days · ~6.5 min/day"`
- "Start Program" button calls a closure/callback — the coordinator handles what happens next

```swift
struct OnboardingView: View {
    var onStart: (Date, Date) -> Void  // injected by coordinator

    var body: some View { ... }
}
```

The coordinator presents this via:
```swift
let view = OnboardingView { startTime, targetTime in
    // coordinator handles program creation + transition to Home
}
let vc = UIHostingController(rootView: view)
navigationController.setViewControllers([vc], animated: false)
```

**Checkpoint:** Onboarding creates a program and schedules day 1 alarm; coordinator pushes Home.

---

## Phase 6 — Home Screen

**Goal:** Main screen shows program state and today's alarm.

New file: `SleepShift/Views/HomeView.swift` — pure SwiftUI view, callbacks for actions.

Key elements:
- Large display: `"Day \(program.currentDay) of \(program.totalDays)"`
- Today's alarm time (prominent, large font)
- Tomorrow's projected time (secondary)
- Current streak — computed from recent `WakeAttempt` records
- Last 7 days list (`WakeAttemptRowView`)
- Fallback button "Schedule Today's Alarm" — visible when no active alarm detected
- `onShowHistory: () -> Void` callback — coordinator pushes `HistoryViewController`
- `.task { await manager.observeAlarms() }` — keeps alarm state live
- Foreground check: called by coordinator from `sceneDidBecomeActive` via `SceneDelegate`

```swift
struct HomeView: View {
    @ObservedObject var manager: SleepShiftManager  // or @Observable / Bindable
    var onShowHistory: () -> Void

    var body: some View { ... }
}
```

**Checkpoint:** Home shows correct day, time, and streak. Fallback button schedules alarm.

---

## Phase 7 — History Screen

**Goal:** Full log of wake attempts.

New file: `SleepShift/Views/HistoryView.swift` — pure SwiftUI view.

Key elements:
- Receives `[WakeAttempt]` fetched by the coordinator (or fetches via injected `ModelContext`)
- List rows showing: day number, scheduled time, actual dismiss time (or "—"), success/fail badge

Coordinator pushes it:
```swift
let view = HistoryView(modelContext: container.mainContext)
let vc = UIHostingController(rootView: view)
navigationController.pushViewController(vc, animated: true)
```

**Checkpoint:** History shows all logged attempts in reverse chronological order.

---

## Phase 8 — Coordinator Routing

**Goal:** Clean coordinator-driven flow: Onboarding → Home ↔ History.

Update `MainCoordinator.swift`:

```swift
class MainCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    let modelContainer: ModelContainer

    init(navigationController: UINavigationController, modelContainer: ModelContainer) {
        self.navigationController = navigationController
        self.modelContainer = modelContainer
    }

    func start() {
        let manager = SleepShiftManager.shared
        if manager.activeProgram != nil {
            showHome()
        } else {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let view = OnboardingView { [weak self] startTime, targetTime in
            Task { @MainActor in
                await self?.handleProgramStart(startTime: startTime, targetTime: targetTime)
            }
        }
        navigationController.setViewControllers([UIHostingController(rootView: view)], animated: false)
    }

    private func handleProgramStart(startTime: Date, targetTime: Date) async {
        let context = modelContainer.mainContext
        let program = ShiftProgram(startWakeTime: startTime, targetWakeTime: targetTime)
        program.isActive = true
        context.insert(program)
        try? context.save()
        SleepShiftManager.shared.setup(context: context)
        await SleepShiftManager.shared.scheduleNextAlarm(forDay: 1)
        showHome()
    }

    func showHome() {
        let view = HomeView(manager: SleepShiftManager.shared, onShowHistory: { [weak self] in
            self?.showHistory()
        })
        navigationController.setViewControllers([UIHostingController(rootView: view)], animated: true)
    }

    func showHistory() {
        let view = HistoryView(modelContext: modelContainer.mainContext)
        navigationController.pushViewController(UIHostingController(rootView: view), animated: true)
    }
}
```

`SceneDelegate` calls `handleForeground()` in `sceneDidBecomeActive`:
```swift
func sceneDidBecomeActive(_ scene: UIScene) {
    Task { await SleepShiftManager.shared.handleForeground() }
}
```

---

## Phase 9 — Background Reliability

**Goal:** Alarm is always scheduled, even if app hasn't been opened.

Update `AppDelegate.swift` — register BGAppRefreshTask in `application(_:didFinishLaunchingWithOptions:)`:

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
├── AppDelegate.swift          ← owns ModelContainer, registers BGTask
├── SceneDelegate.swift        ← calls manager.setup(), handleForeground()
├── MainCoordinator.swift      ← all navigation logic
├── RootViewController.swift   ← kept from template (coordinator entry point)
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
└── SleepShift.entitlements   ← add Alarms entitlement here
```

---

## Build Order Summary

| Phase | What | Unblocks |
|-------|------|----------|
| 0 | Project setup (iOS 26, AppDelegate ModelContainer, Info.plist, capabilities) | Everything |
| 1 | SwiftData models | Manager, Views |
| 2 | SleepShiftManager (no AlarmKit) | Views, logic |
| 3 | AlarmKit integration | Real alarms, Intents |
| 4 | AppIntents | Alarm button actions |
| 5 | Onboarding | Start program flow |
| 6 | Home | Daily use |
| 7 | History | Logging visibility |
| 8 | Coordinator routing (Onboarding → Home ↔ History) | Full app flow |
| 9 | Background refresh | Reliability |
| 10 | Polish | Ship |

---

## Known Constraints / Gotchas

- **AlarmKit requires physical device** — simulator does not deliver alarms
- **`nonisolated` on `WakeShiftMetadata`** — mandatory in Xcode 26 due to default MainActor isolation
- **One alarm at a time** — always cancel existing before scheduling new
- **AppIntents lock screen** — test from locked device early; intent execution context is different from foreground
- **SwiftData ModelContainer** — owned by `AppDelegate`, injected into coordinator; don't create multiple containers
- **`alarmManager.alarmUpdates` is `AsyncSequence`** — iterate with `.task {}` in the SwiftUI view, not `onAppear`
- **Coordinator owns navigation, views own none** — SwiftUI views communicate out via callbacks/closures only; no `NavigationLink`, no `NavigationStack`
