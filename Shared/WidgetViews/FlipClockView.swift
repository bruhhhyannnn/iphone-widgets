import SwiftUI
import WidgetKit

struct FlipClockBackground: View {
    var look: WidgetLook
    var body: some View {
        switch look {
        case .light: LinearGradient(colors: [Color(hex: 0xEDEAE4), Color(hex: 0xE2DED6)], startPoint: .top, endPoint: .bottom)
        case .dark: LinearGradient(colors: [Color(hex: 0x1E1F23), Color(hex: 0x141518)], startPoint: .top, endPoint: .bottom)
        case .glass: Color.clear
        }
    }
}

struct FlipClockContent: View {
    var date: Date
    var settings: FlipSettings
    var family: WidgetFamily
    var look: WidgetLook

    private var palette: Palette { Palette(look, accent: settings.accent) }

    private var hourText: String {
        if settings.use24Hour { return Fmt.string(date, "HH") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h"
        return formatter.string(from: date)
    }
    private var minuteText: String { Fmt.string(date, "mm") }
    private var period: String? {
        guard !settings.use24Hour else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "a"
        return formatter.string(from: date).uppercased()
    }

    var body: some View {
        if family == .systemSmall { small } else { medium }
    }

    private var small: some View {
        VStack(spacing: 8) {
            if settings.showDate {
                HStack {
                    Text(Fmt.string(date, "EEE").uppercased())
                        .foregroundStyle(palette.accent)
                        .widgetAccentable()
                    Spacer()
                    Text(Fmt.template(date, "MMMd").uppercased())
                        .foregroundStyle(palette.secondary)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1)
            }
            HStack(spacing: 6) {
                FlipTile(text: hourText, palette: palette, fontSize: 50)
                FlipTile(text: minuteText, palette: palette, fontSize: 50)
            }
            if let period {
                Text(period)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(palette.secondary)
            }
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 10) {
            FlipTile(text: hourText, palette: palette, fontSize: 84)
            FlipTile(text: minuteText, palette: palette, fontSize: 84)
            VStack(alignment: .leading, spacing: 4) {
                if let period {
                    Text(period)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(palette.accent)
                        .widgetAccentable()
                }
                Spacer(minLength: 0)
                if settings.showDate {
                    Text(Fmt.string(date, "EEEE"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primary)
                        .minimumScaleFactor(0.7)
                    Text(Fmt.template(date, "MMMMd"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondary)
                }
            }
            .lineLimit(1)
            .frame(width: 72, alignment: .leading)
        }
        .padding(14)
    }
}

/// One split-flap card: two halves, a hinge line and side pins.
struct FlipTile: View {
    var text: String
    var palette: Palette
    var fontSize: CGFloat

    private var topColor: Color {
        switch palette.look {
        case .light: Color(hex: 0xFFFFFF)
        case .dark: Color(hex: 0x34353A)
        case .glass: Color.white.opacity(0.20)
        }
    }
    private var bottomColor: Color {
        switch palette.look {
        case .light: Color(hex: 0xF3F1EC)
        case .dark: Color(hex: 0x2A2B2F)
        case .glass: Color.white.opacity(0.12)
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack {
            VStack(spacing: 0) {
                topColor
                bottomColor
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(palette.stroke, lineWidth: 0.5))
            .shadow(color: .black.opacity(palette.look == .light ? 0.12 : 0.35), radius: 3, y: 2)

            Text(text)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(palette.primary)
                .contentTransition(.numericText())
                .padding(.horizontal, 4)

            // Hinge
            Rectangle()
                .fill(palette.look == .light ? Color.black.opacity(0.12) : Color.black.opacity(0.45))
                .frame(height: 1.5)
            HStack {
                Capsule().frame(width: 3, height: 9)
                Spacer()
                Capsule().frame(width: 3, height: 9)
            }
            .foregroundStyle(palette.tertiary)
            .padding(.horizontal, 2)
        }
    }
}
