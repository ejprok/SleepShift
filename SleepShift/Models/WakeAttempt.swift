import SwiftData
import Foundation

@Model
class WakeAttempt {
    var day: Int
    var scheduledTime: Date
    var dismissedTime: Date?
    var successful: Bool
    @Relationship(deleteRule: .nullify) var program: ShiftProgram?

    init(day: Int, scheduledTime: Date, program: ShiftProgram?) {
        self.day = day
        self.scheduledTime = scheduledTime
        self.dismissedTime = nil
        self.successful = false
        self.program = program
    }
}
