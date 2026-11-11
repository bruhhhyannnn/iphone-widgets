import SwiftUI
import WidgetKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// How a widget is drawn: on a light card, a dark card, or as clear Liquid Glass.
enum WidgetLook: String, CaseIterable, Identifiable {
    case light, dark, glass
    var id: String { rawValue }
    var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .glass: "Glass"
        }
    }

    /// Inside a real widget: Clear/Tinted Home Screen styles render widgets as glass
    /// (rendering mode is not full color); otherwise follow the user's appearance setting.
    static func resolve(_ appearance: Appearance, scheme: ColorScheme, renderingMode: WidgetRenderingMode) -> WidgetLook {
        if renderingMode != .fullColor { return .glass }
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .auto: return scheme == .dark ? .dark : .light
        }
    }

    /// In the app's preview: "Light"/"Dark" previews still respect a widget's forced appearance.
    static func preview(_ previewLook: WidgetLook, appearance: Appearance) -> WidgetLook {
        guard previewLook != .glass else { return .glass }
        switch appearance {
        case .auto: return previewLook
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct Palette {
    let look: WidgetLook
    let accentChoice: Accent

    init(_ look: WidgetLook, accent: Accent = .red) {
        self.look = look
        self.accentChoice = accent
    }

    var isGlass: Bool { look == .glass }
    var accent: Color { accentChoice.color(on: look) }

    var background: Color {
        switch look {
        case .light: Color(hex: 0xF4F1EB)
        case .dark: Color(hex: 0x1C1D21)
        case .glass: .clear
        }
    }
    var primary: Color { look == .light ? Color(hex: 0x1D1D1F) : .white }
    var secondary: Color { look == .light ? Color(hex: 0x1D1D1F, opacity: 0.58) : .white.opacity(0.66) }
    var tertiary: Color { look == .light ? Color(hex: 0x1D1D1F, opacity: 0.34) : .white.opacity(0.40) }
    var fill: Color {
        switch look {
        case .light: Color.black.opacity(0.06)
        case .dark: Color.white.opacity(0.09)
        case .glass: Color.white.opacity(0.16)
        }
    }
    var stroke: Color {
        switch look {
        case .light: Color.black.opacity(0.10)
        case .dark: Color.white.opacity(0.12)
        case .glass: Color.white.opacity(0.30)
        }
    }
    /// Text drawn on top of an accent-filled shape.
    var onAccent: Color { isGlass ? .black.opacity(0.85) : .white }
}

/// Native widget sizes on a 6.1–6.3" iPhone, used to draw previews in the app.
enum WidgetSize {
    static func points(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: CGSize(width: 170, height: 170)
        case .systemMedium: CGSize(width: 364, height: 170)
        case .systemLarge: CGSize(width: 364, height: 382)
        default: CGSize(width: 170, height: 170)
        }
    }
    static let cornerRadius: CGFloat = 24
}

/// Small deterministic random generator so stars/paper grain don't flicker between refreshes.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
}
