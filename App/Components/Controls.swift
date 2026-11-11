import SwiftUI
import WidgetKit

extension Color {
    static let brand = Color(hex: 0xF93E3B)
}

/// A row of Liquid Glass capsules acting as a segmented control.
struct GlassChips<Option: Hashable>: View {
    var options: [Option]
    @Binding var selection: Option
    var tint: Color = .brand
    var label: (Option) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        let isOn = option == selection
                        Button {
                            withAnimation(.snappy) { selection = option }
                        } label: {
                            Text(label(option))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isOn ? Color.white : Color.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(isOn ? Glass.regular.tint(tint).interactive() : Glass.regular.interactive(), in: .capsule)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollClipDisabled()
    }
}

struct AccentPicker: View {
    @Binding var selection: Accent

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Accent.allCases) { accent in
                    Button {
                        withAnimation(.snappy) { selection = accent }
                    } label: {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if selection == accent {
                                    Circle().strokeBorder(Color.primary, lineWidth: 2.5).padding(-5)
                                }
                            }
                            .padding(5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accent.rawValue.capitalized)
                }
            }
        }
        .scrollClipDisabled()
    }
}

/// A labelled setting. Wide controls go under the title, short ones beside it.
struct SettingRow<Control: View>: View {
    var title: String
    var stacked = false
    @ViewBuilder var control: () -> Control

    var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: 8) {
                titleView
                control()
            }
        } else {
            // Side by side when it fits, otherwise the control drops under the title.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    titleView
                    Spacer(minLength: 8)
                    control()
                }
                VStack(alignment: .leading, spacing: 8) {
                    titleView
                    control()
                }
            }
        }
    }

    private var titleView: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

/// A call-to-action row like "Set your location — Set up".
struct ActionRow: View {
    var title: String
    var detail: String
    var button: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(button, action: action)
                .buttonStyle(.glassProminent)
                .tint(.brand)
        }
    }
}

/// The rounded card each widget lives in on the Widgets tab.
struct WidgetCard<Preview: View, Controls: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var preview: () -> Preview
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.bold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            preview()
            VStack(alignment: .leading, spacing: 16) {
                controls()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}

/// Draws a widget at its real size and scales it down to fit the screen.
struct WidgetPreview<Content: View, Background: View>: View {
    var family: WidgetFamily
    var look: WidgetLook
    @ViewBuilder var content: () -> Content
    @ViewBuilder var background: () -> Background

    var body: some View {
        let size = WidgetSize.points(for: family)
        let shape = RoundedRectangle(cornerRadius: WidgetSize.cornerRadius, style: .continuous)
        PreviewStage(look: look) {
            ScaledToFit(size: size) {
                Group {
                    if look == .glass {
                        content()
                            .frame(width: size.width, height: size.height)
                            .glassEffect(.clear, in: shape)
                    } else {
                        content()
                            .frame(width: size.width, height: size.height)
                            .background { background() }
                            .clipShape(shape)
                            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                    }
                }
                .environment(\.colorScheme, look == .light ? .light : .dark)
            }
        }
    }
}

/// Behind glass previews, show a colorful "wallpaper" so the glass has something to refract.
struct PreviewStage<Content: View>: View {
    var look: WidgetLook
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(look == .glass ? 16 : 0)
            .background {
                if look == .glass {
                    SampleWallpaper()
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
            }
    }
}

struct SampleWallpaper: View {
    var body: some View {
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.55, 0.5], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ], colors: [
            Color(hex: 0x1B2A6B), Color(hex: 0x7A3FA0), Color(hex: 0xF0605A),
            Color(hex: 0x2A6FB0), Color(hex: 0xE8A35C), Color(hex: 0xC2417A),
            Color(hex: 0x0F5B63), Color(hex: 0x3BA88A), Color(hex: 0x23305E),
        ])
    }
}

struct ScaledToFit<Content: View>: View {
    var size: CGSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let scale = min(1, geo.size.width / size.width)
            content()
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
        .frame(maxWidth: size.width)
    }
}

extension WidgetFamily {
    var shortLabel: String {
        switch self {
        case .systemSmall: "Small"
        case .systemMedium: "Medium"
        case .systemLarge: "Large"
        default: "Widget"
        }
    }
}
