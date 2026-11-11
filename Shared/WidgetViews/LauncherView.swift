import SwiftUI
import WidgetKit

struct LauncherBackground: View {
    var drawer: Drawer
    var photo: UIImage?
    var look: WidgetLook

    var body: some View {
        if look == .glass {
            Color.clear
        } else {
            DrawerSceneView(scene: drawer.scene, photo: photo, dark: drawer.appearance != .light)
        }
    }
}

/// The decorative backgrounds a drawer can use.
struct DrawerSceneView: View {
    var scene: DrawerScene
    var photo: UIImage?
    var dark: Bool

    var body: some View {
        switch scene {
        case .plain:
            dark ? Color(hex: 0x1C1D21) : Color(hex: 0xF4F1EB)
        case .retro:
            RetroSunset()
        case .aurora:
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                Color(hex: 0x081C2C), Color(hex: 0x0F3B4A), Color(hex: 0x1B1340),
                Color(hex: 0x0E6B5C), Color(hex: 0x2FCB8E), Color(hex: 0x5B2C8F),
                Color(hex: 0x06121E), Color(hex: 0x0D3A3F), Color(hex: 0x1A0F33),
            ])
        case .dusk:
            LinearGradient(colors: [Color(hex: 0x2A1B5C), Color(hex: 0x8E3B8C), Color(hex: 0xF0705A), Color(hex: 0xFFC56E)],
                           startPoint: .top, endPoint: .bottom)
        case .ocean:
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.45, 0.55], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                Color(hex: 0x0B2A4A), Color(hex: 0x1B5E8C), Color(hex: 0x0E3E66),
                Color(hex: 0x167C8C), Color(hex: 0x37B6C2), Color(hex: 0x1F6FA8),
                Color(hex: 0x0A2340), Color(hex: 0x0F4F73), Color(hex: 0x0B2F55),
            ])
        case .ember:
            ZStack {
                Color(hex: 0x1A0A08)
                RadialGradient(colors: [Color(hex: 0xFF7A2F), Color(hex: 0xB3261E), .clear],
                               center: .bottom, startRadius: 10, endRadius: 260)
            }
        case .graphite:
            LinearGradient(colors: [Color(hex: 0x3A3B40), Color(hex: 0x1C1D20)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .photo:
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.12))
            } else {
                LinearGradient(colors: [Color(hex: 0x3A3B40), Color(hex: 0x1C1D20)], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

/// A 70s-style striped sun setting into the bottom of the widget.
struct RetroSunset: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let sunSize = min(w * 0.9, h * 1.5)
            ZStack {
                LinearGradient(colors: [Color(hex: 0x1D1B3A), Color(hex: 0x4B2A5C), Color(hex: 0xC2566B)],
                               startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFD27A), Color(hex: 0xFF8A4C), Color(hex: 0xE2486B)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: sunSize, height: sunSize)
                    .mask {
                        VStack(spacing: 0) {
                            Rectangle().frame(height: sunSize * 0.5)
                            ForEach(0..<6, id: \.self) { i in
                                Rectangle().frame(height: sunSize * 0.035 * Double(6 - i) / 3)
                                Color.clear.frame(height: sunSize * 0.012 * Double(i + 1))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .position(x: w / 2, y: h - sunSize * 0.12)
            }
        }
    }
}

struct LauncherContent: View {
    var drawer: Drawer
    var icons: [UUID: UIImage]
    var family: WidgetFamily
    var look: WidgetLook
    var launchThroughApp: Bool
    /// False in the app's preview so tapping an icon doesn't leave the editor.
    var interactive: Bool = true

    private var palette: Palette { Palette(look, accent: drawer.tint) }

    private var layout: (columns: Int, rows: Int) {
        switch family {
        case .systemSmall: (2, 2)
        case .systemLarge: (4, 4)
        default: (4, 2)
        }
    }

    private var iconSize: CGFloat {
        switch family {
        case .systemSmall: drawer.showLabels ? 46 : 56
        case .systemLarge: drawer.showLabels ? 54 : 62
        default: drawer.showLabels ? 46 : 56
        }
    }

    var body: some View {
        let capacity = layout.columns * layout.rows
        let apps = Array(drawer.apps.prefix(capacity))
        Group {
            if apps.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "plus.app.fill").font(.system(size: 28))
                    Text("Add apps to \(drawer.name) in Glassboard")
                        .font(.system(size: 12, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(0..<layout.rows, id: \.self) { row in
                        GridRow {
                            ForEach(0..<layout.columns, id: \.self) { column in
                                let index = row * layout.columns + column
                                if index < apps.count {
                                    cell(apps[index])
                                } else {
                                    Color.clear
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func cell(_ app: LauncherApp) -> some View {
        let label = VStack(spacing: 4) {
            LauncherIcon(app: app, image: icons[app.id], style: drawer.style, tint: drawer.tint, look: look, size: iconSize)
            if drawer.showLabels {
                Text(app.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())

        if interactive, let url = launchURL(for: app) {
            if family == .systemSmall {
                Button(intent: LaunchAppIntent(url: url)) { label }
                    .buttonStyle(.plain)
            } else {
                Link(destination: url) { label }
            }
        } else {
            label
        }
    }

    private func launchURL(for app: LauncherApp) -> URL? {
        guard let target = URL(string: app.url.trimmingCharacters(in: .whitespaces)) else { return nil }
        guard launchThroughApp else { return target }
        var components = URLComponents()
        components.scheme = "glassboard"
        components.host = "launch"
        components.queryItems = [URLQueryItem(name: "url", value: target.absoluteString)]
        return components.url ?? target
    }
}

struct LauncherIcon: View {
    var app: LauncherApp
    var image: UIImage?
    var style: IconStyle
    var tint: Accent
    var look: WidgetLook
    var size: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.235, style: .continuous)
    }

    var body: some View {
        switch style {
        case .color:
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .frame(width: size, height: size)
                    .clipShape(shape)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            } else {
                plate(fill: tint.color, foreground: .white)
            }
        case .tinted:
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .saturation(0)
                    .colorMultiply(look == .glass ? .white : tint.color.mix(with: .white, by: 0.35))
                    .frame(width: size, height: size)
                    .clipShape(shape)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            } else {
                plate(fill: tint.color.opacity(0.85), foreground: .white)
            }
        case .mono:
            plate(fill: look == .light ? Color.white.opacity(0.85) : Color.black.opacity(0.35),
                  foreground: look == .light ? Color(hex: 0x1D1D1F) : .white)
        case .ghost:
            Image(systemName: app.symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 4)
                .frame(width: size, height: size)
                .widgetAccentable()
        }
    }

    private func plate(fill: Color, foreground: Color) -> some View {
        ZStack {
            shape.fill(fill)
            shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            Image(systemName: app.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(foreground)
                .widgetAccentable()
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
    }
}
