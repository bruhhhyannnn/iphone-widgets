import PhotosUI
import SwiftUI
import WidgetKit

struct LauncherHomeView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedID: UUID?
    @State private var family: WidgetFamily = .systemMedium
    @State private var showPicker = false
    @State private var editingApp: LauncherApp?
    @State private var photoItem: PhotosPickerItem?
    @State private var renaming = false
    @State private var nameDraft = ""
    @State private var confirmDelete = false

    private var drawer: Drawer {
        model.drawerList.drawers.first { $0.id == selectedID } ?? model.drawerList.drawers.first ?? Drawer()
    }

    private func update(_ change: (inout Drawer) -> Void) {
        var copy = drawer
        change(&copy)
        model.updateDrawer(copy)
    }

    var body: some View {
        @Bindable var model = model
        let drawer = drawer
        let look = WidgetLook.preview(model.previewLook, appearance: drawer.appearance)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                drawerTabs

                WidgetCard(title: drawer.name, subtitle: "\(drawer.apps.count) apps · Small shows 4, Medium 8, Large 16") {
                    WidgetPreview(family: family, look: look) {
                        LauncherContent(drawer: drawer, icons: PreviewIcons.icons(for: drawer), family: family,
                                        look: look, launchThroughApp: false, interactive: false)
                    } background: {
                        LauncherBackground(drawer: drawer, photo: PreviewIcons.photo(for: drawer), look: look)
                    }
                } controls: {
                    SettingRow(title: "Preview") {
                        GlassChips(options: WidgetLook.allCases, selection: $model.previewLook) { $0.label }
                            .fixedSize()
                    }
                    SettingRow(title: "Size") {
                        GlassChips(options: [WidgetFamily.systemSmall, .systemMedium, .systemLarge], selection: $family) { $0.shortLabel }
                            .fixedSize()
                    }
                    HStack {
                        Button {
                            showPicker = true
                        } label: {
                            Label("Add App", systemImage: "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.brand)
                        Button {
                            nameDraft = drawer.name
                            renaming = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.headline)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                    }
                }

                if !drawer.apps.isEmpty { appsCard(drawer) }
                styleCard(drawer)

                if model.drawerList.drawers.count > 1 {
                    Button("Delete \(drawer.name)", role: .destructive) { confirmDelete = true }
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Launcher")
        .sheet(isPresented: $showPicker) {
            AppPickerView(existingNames: Set(drawer.apps.map(\.name))) { app in
                update { $0.apps.append(app) }
            }
        }
        .sheet(item: $editingApp) { app in
            NavigationStack {
                AppEditorView(app: app) { edited in
                    update { drawer in
                        if let index = drawer.apps.firstIndex(where: { $0.id == edited.id }) {
                            if drawer.apps[index].iconFile != edited.iconFile {
                                ImageStore.delete(drawer.apps[index].iconFile, in: ImageStore.iconsFolder)
                            }
                            drawer.apps[index] = edited
                        }
                    }
                }
            }
        }
        .alert("Rename drawer", isPresented: $renaming) {
            TextField("Name", text: $nameDraft)
            Button("Save") {
                let name = nameDraft.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { update { $0.name = name } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this drawer?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.deleteDrawer(drawer)
                selectedID = model.drawerList.drawers.first?.id
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .onAppear {
            if selectedID == nil { selectedID = model.drawerList.drawers.first?.id }
        }
    }

    // MARK: Sections

    private var drawerTabs: some View {
        HStack(spacing: 8) {
            GlassChips(options: model.drawerList.drawers.map(\.id),
                       selection: Binding(get: { drawer.id }, set: { selectedID = $0 })) { id in
                model.drawerList.drawers.first { $0.id == id }?.name ?? "Drawer"
            }
            Button {
                let new = model.addDrawer()
                withAnimation(.snappy) { selectedID = new.id }
            } label: {
                Image(systemName: "plus").font(.headline).padding(4)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("New drawer")
        }
    }

    private func appsCard(_ drawer: Drawer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apps").font(.title3.weight(.bold))
            ForEach(Array(drawer.apps.enumerated()), id: \.element.id) { index, app in
                HStack(spacing: 12) {
                    LauncherIcon(app: app, image: PreviewIcons.image(app.iconFile), style: .color,
                                 tint: drawer.tint, look: .dark, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name).font(.body.weight(.semibold))
                        Text(app.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Menu {
                        Button("Edit", systemImage: "pencil") { editingApp = app }
                        Button("Move up", systemImage: "arrow.up") { move(index, by: -1) }
                            .disabled(index == 0)
                        Button("Move down", systemImage: "arrow.down") { move(index, by: 1) }
                            .disabled(index == drawer.apps.count - 1)
                        Button("Test link", systemImage: "arrow.up.forward.app") {
                            if let url = URL(string: app.url) { UIApplication.shared.open(url) }
                        }
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            update { $0.apps.removeAll { $0.id == app.id } }
                            ImageStore.delete(app.iconFile, in: ImageStore.iconsFolder)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                }
                if index == 3 || index == 7 || index == 15 {
                    HStack {
                        Rectangle().frame(height: 0.5)
                        Text(index == 3 ? "Small ends here" : index == 7 ? "Medium ends here" : "Large ends here")
                            .font(.caption2.weight(.semibold))
                            .fixedSize()
                        Rectangle().frame(height: 0.5)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    private func styleCard(_ drawer: Drawer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Style").font(.title3.weight(.bold))
            SettingRow(title: "Icons") {
                GlassChips(options: IconStyle.allCases, selection: Binding(get: { drawer.style }, set: { value in update { $0.style = value } })) { $0.label }
                    .fixedSize()
            }
            SettingRow(title: "Scene", stacked: true) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(DrawerScene.allCases) { scene in
                            Button {
                                update { $0.scene = scene }
                            } label: {
                                VStack(spacing: 6) {
                                    DrawerSceneView(scene: scene, photo: scene == .photo ? PreviewIcons.photo(for: drawer) : nil,
                                                    dark: drawer.appearance != .light)
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(drawer.scene == scene ? Color.brand : Color.clear, lineWidth: 3)
                                        }
                                    Text(scene.label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(drawer.scene == scene ? Color.primary : Color.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }
            if drawer.scene == .photo {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(drawer.photoFile == nil ? "Choose a photo" : "Change photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            if drawer.style == .tinted || drawer.style == .color {
                SettingRow(title: "Tint", stacked: true) {
                    AccentPicker(selection: Binding(get: { drawer.tint }, set: { value in update { $0.tint = value } }))
                }
            }
            SettingRow(title: "Plates") {
                GlassChips(options: [Appearance.light, .dark],
                           selection: Binding(get: { drawer.appearance == .light ? .light : .dark },
                                              set: { value in update { $0.appearance = value } })) { $0.label }
                    .fixedSize()
            }
            Toggle("App names under icons", isOn: Binding(get: { drawer.showLabels }, set: { value in update { $0.showLabels = value } }))
                .tint(.brand)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    // MARK: Actions

    private func move(_ index: Int, by offset: Int) {
        update { drawer in
            let target = index + offset
            guard drawer.apps.indices.contains(index), drawer.apps.indices.contains(target) else { return }
            drawer.apps.swapAt(index, target)
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let file = ImageStore.save(image, in: ImageStore.backgroundsFolder, maxPixel: 900, jpeg: true)
        else { return }
        let old = drawer.photoFile
        update {
            $0.photoFile = file
            $0.scene = .photo
        }
        ImageStore.delete(old, in: ImageStore.backgroundsFolder)
        photoItem = nil
    }
}

/// Small in-memory cache so the editor doesn't re-read icons from disk on every redraw.
enum PreviewIcons {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ file: String?) -> UIImage? {
        guard let file else { return nil }
        if let cached = cache.object(forKey: file as NSString) { return cached }
        let folder = file.hasSuffix(".jpg") ? ImageStore.backgroundsFolder : ImageStore.iconsFolder
        guard let image = ImageStore.image(file, in: folder, maxPixel: file.hasSuffix(".jpg") ? 900 : 180) else { return nil }
        cache.setObject(image, forKey: file as NSString)
        return image
    }

    static func icons(for drawer: Drawer) -> [UUID: UIImage] {
        var icons: [UUID: UIImage] = [:]
        for app in drawer.apps {
            if let image = image(app.iconFile) { icons[app.id] = image }
        }
        return icons
    }

    static func photo(for drawer: Drawer) -> UIImage? {
        image(drawer.photoFile)
    }
}
