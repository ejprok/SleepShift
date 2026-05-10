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
        let totalMinutes = abs(Calendar.current.dateComponents([.minute], from: targetWakeTime, to: startWakeTime).minute ?? 0)
        return max(1, Int(ceil(Double(totalMinutes) / 6.5)))
    }

    init(startWakeTime: Date, targetWakeTime: Date, startDate: Date = .now) {
        self.startWakeTime = startWakeTime
        self.targetWakeTime = targetWakeTime
        self.startDate = startDate
        self.currentDay = 1
        self.isActive = false
    }
}
