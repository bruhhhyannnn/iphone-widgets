import SwiftUI

/// Sheet for adding apps to a drawer.
struct AppPickerView: View {
    var existingNames: Set<String>
    var onAdd: (LauncherApp) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var adding: String?
    @State private var added: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AppEditorView(app: nil) { app in
                            onAdd(app)
                            dismiss()
                        }
                    } label: {
                        Label("Any app, website or Shortcut…", systemImage: "plus.square.dashed")
                    }
                } footer: {
                    Text("For apps that aren't listed, add them with their link, or make a Shortcut that opens the app and launch that.")
                }

                Section("Apps") {
                    ForEach(AppCatalog.search(query)) { item in
                        Button {
                            Task { await add(item) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.brand.gradient))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name).foregroundStyle(Color.primary)
                                    Text(item.url).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if adding == item.name {
                                    ProgressView()
                                } else if added.contains(item.name) || existingNames.contains(item.name) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brand)
                                } else {
                                    Image(systemName: "plus.circle").foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(adding != nil)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search apps")
            .navigationTitle("Add App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func add(_ item: CatalogApp) async {
        adding = item.name
        let iconFile = await IconSearch.fetchIcon(for: item.storeTerm)
        onAdd(LauncherApp(name: item.name, url: item.url, iconFile: iconFile, symbol: item.symbol))
        added.insert(item.name)
        adding = nil
    }
}

/// Create or edit a launcher entry: any URL scheme, website, or Shortcut.
struct AppEditorView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case app, website, shortcut
        var id: String { rawValue }
        var label: String {
            switch self {
            case .app: "App link"
            case .website: "Website"
            case .shortcut: "Shortcut"
            }
        }
    }

    var app: LauncherApp?
    var onSave: (LauncherApp) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: Kind = .app
    @State private var value = ""
    @State private var symbol = "app.fill"
    @State private var iconFile: String?
    @State private var results: [IconSearch.Result] = []
    @State private var searching = false
    @State private var downloading: URL?

    private static let symbols = [
        "app.fill", "star.fill", "heart.fill", "bolt.fill", "camera.fill", "music.note", "play.fill", "gamecontroller.fill",
        "message.fill", "phone.fill", "envelope.fill", "globe", "cart.fill", "bag.fill", "creditcard.fill", "car.fill",
        "airplane", "house.fill", "book.fill", "pencil", "doc.fill", "folder.fill", "map.fill", "leaf.fill",
        "dumbbell.fill", "fork.knife", "cup.and.saucer.fill", "film.fill", "tv.fill", "headphones", "gearshape.fill", "sparkles",
    ]

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Picker("Opens", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.label).tag($0) }
                }
                TextField(placeholder, text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(kind == .shortcut ? .default : .URL)
            } footer: {
                Text(footer)
            }

            Section("Icon") {
                HStack(spacing: 14) {
                    LauncherIcon(app: draft, image: ImageStore.image(iconFile, in: ImageStore.iconsFolder),
                                 style: .color, tint: .red, look: .dark, size: 56)
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            Task { await findIcons() }
                        } label: {
                            Label(searching ? "Searching…" : "Find icon on the App Store", systemImage: "magnifyingglass")
                        }
                        .disabled(name.isEmpty || searching)
                        if iconFile != nil {
                            Button("Use symbol instead", role: .destructive) { iconFile = nil }
                                .font(.footnote)
                        }
                    }
                }
                if !results.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(results) { result in
                                Button {
                                    Task { await pick(result) }
                                } label: {
                                    VStack(spacing: 4) {
                                        AsyncImage(url: result.artwork) { image in
                                            image.resizable()
                                        } placeholder: {
                                            Color.gray.opacity(0.2)
                                        }
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay {
                                            if downloading == result.artwork { ProgressView() }
                                        }
                                        Text(result.name).font(.caption2).lineLimit(1).frame(width: 64)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Symbol (Mono & Ghost styles)") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                    ForEach(Self.symbols, id: \.self) { name in
                        Button {
                            symbol = name
                        } label: {
                            Image(systemName: name)
                                .font(.system(size: 17))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(symbol == name ? Color.brand.opacity(0.25) : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(app == nil ? "New Item" : "Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(draft)
                    if app != nil { dismiss() }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || resolvedURL == nil)
            }
        }
        .onAppear(perform: load)
    }

    private var placeholder: String {
        switch kind {
        case .app: "spotify://"
        case .website: "https://example.com"
        case .shortcut: "Shortcut name"
        }
    }

    private var footer: String {
        switch kind {
        case .app: "The app's URL scheme. Search the web for “<app name> URL scheme” if it isn't in the list."
        case .website: "Opens in Safari (or the site's app, if it supports universal links)."
        case .shortcut: "Runs a Shortcut from the Shortcuts app. Use one with an “Open App” action to launch any app."
        }
    }

    private var resolvedURL: String? {
        let text = value.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        switch kind {
        case .app:
            return text.contains(":") ? text : text + "://"
        case .website:
            return text.hasPrefix("http") ? text : "https://" + text
        case .shortcut:
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            return "shortcuts://run-shortcut?name=\(encoded)"
        }
    }

    private var draft: LauncherApp {
        LauncherApp(id: app?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespaces),
                    url: resolvedURL ?? "", iconFile: iconFile, symbol: symbol)
    }

    private func load() {
        guard let app, name.isEmpty else { return }
        name = app.name
        symbol = app.symbol
        iconFile = app.iconFile
        if app.url.hasPrefix("shortcuts://run-shortcut?name=") {
            kind = .shortcut
            value = String(app.url.dropFirst("shortcuts://run-shortcut?name=".count)).removingPercentEncoding ?? ""
        } else if app.url.hasPrefix("http") {
            kind = .website
            value = app.url
        } else {
            kind = .app
            value = app.url
        }
    }

    private func findIcons() async {
        searching = true
        results = await IconSearch.search(name)
        searching = false
    }

    private func pick(_ result: IconSearch.Result) async {
        downloading = result.artwork
        if let file = await IconSearch.downloadIcon(from: result.artwork) {
            iconFile = file
        }
        downloading = nil
    }
}
