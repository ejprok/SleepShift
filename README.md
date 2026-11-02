# SleepShift

An iPhone alarm experiment for gradually moving a wake-up time earlier, using AlarmKit and SwiftData.

## Try the dawn redesign

Open `SleepShift.xcodeproj`, select the SleepShift scheme, and run on iOS 26 or later. The local `design/dawn-facelift` branch contains the refreshed setup, morning dashboard, and wake history.

- Setup: choose your usual and earlier target times, then begin the shift.
- Dashboard: review the planned wake time, scheduling status, and progression toward your target.
- History: review dated attempts and recorded outcomes.
- Debug builds retain the hammer menu for developer alarm controls.

Alarm permission and actual delivery need a physical-device check. The redesign does not change the scheduling engine or data model.

## Review checklist

Check setup with valid and invalid target times, an existing program, empty and populated history, light/dark appearance, larger text and VoiceOver. Deny alarm permission and verify that the dashboard shows the error and offers scheduling again. Check real alarm delivery separately on a device.

Validation for this change: Swift frontend parsing and project plist lint pass. A complete Xcode build was attempted but blocked while resolving the existing EJComponent package by sandbox filesystem permissions; no successful iOS build or visual simulator run is claimed.
