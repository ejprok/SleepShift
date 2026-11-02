import SwiftUI

enum ShiftStyle {
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 1, green: 0.68, blue: 0.47, alpha: 1) : UIColor(red: 0.64, green: 0.25, blue: 0.14, alpha: 1) })
    static let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1) : UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1) })
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let dawn = LinearGradient(colors: [accent.opacity(0.19), background], startPoint: .topTrailing, endPoint: .bottomLeading)
}
struct ShiftCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(ShiftStyle.surface, in: RoundedRectangle(cornerRadius: 28))
    }
}
struct ShiftPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 18)
            .foregroundStyle(ShiftStyle.background)
            .background(ShiftStyle.accent, in: RoundedRectangle(cornerRadius: 20))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
struct DawnIllustration: View {
    var body: some View {
        ZStack {
            Circle().fill(ShiftStyle.accent.opacity(0.07)).frame(width: 158, height: 158)
            Circle().fill(ShiftStyle.accent.opacity(0.1)).frame(width: 116, height: 116)
            Image(systemName: "sun.horizon.fill").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(ShiftStyle.accent)
        }.frame(maxWidth: .infinity).accessibilityHidden(true)
    }
}
