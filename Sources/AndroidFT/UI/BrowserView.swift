import SwiftUI
import UniformTypeIdentifiers

struct BrowserView: View {
    @Environment(AppModel.self) private var model
    @State private var renameText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var sortOrder = [KeyPathComparator(\MTPEntry.name, comparator: .localizedStandard)]

    private var sortedEntries: [MTPEntry] { model.entries.sorted(using: sortOrder) }

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $model.selectedStorageID) {
                Section(model.deviceInfo?.displayName ?? "Device") {
                    ForEach(model.storages) { storage in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(storage.name, systemImage: storage.name.localizedCaseInsensitiveContains("card") ? "sdcard" : "internaldrive")
                            Text("\(Format.size(storage.freeSpace)) free of \(Format.size(storage.capacity))")
                                .font(.caption).foregroundStyle(.secondary).padding(.leading, 26)
                        }
                        .tag(storage.id)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                pathBar
                Divider()
                fileTable
                Divider()
                HStack {
                    if model.isLoading { ProgressView().controlSize(.small) }
                    Text(model.statusText).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
            }
        }
        .toolbar { toolbarItems }
        .navigationTitle(model.path.last?.name ?? model.currentStorage?.name ?? "AndroidFT")
        .navigationSubtitle(model.deviceInfo?.displayName ?? "")
        .alert("Rename", isPresented: Binding(get: { model.renaming != nil },
                                               set: { if !$0 { model.renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let entry = model.renaming { model.rename(entry, to: renameText) }
                model.renaming = nil
            }
            Button("Cancel", role: .cancel) { model.renaming = nil }
        } message: {
            Text("Enter a new name for \"\(model.renaming?.name ?? "")\".")
        }
        .onChange(of: model.renaming) { _, entry in renameText = entry?.name ?? "" }
    }

    // MARK: Path bar

    private var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button(model.currentStorage?.name ?? "Root") { model.jump(toDepth: 0) }
                    .buttonStyle(.plain)
                    .fontWeight(model.path.isEmpty ? .semibold : .regular)
                ForEach(Array(model.path.enumerated()), id: \.element.id) { index, folder in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    Button(folder.name) { model.jump(toDepth: index + 1) }
                        .buttonStyle(.plain)
                        .fontWeight(index == model.path.count - 1 ? .semibold : .regular)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .background(.bar)
    }

    // MARK: Table

    private var fileTable: some View {
        @Bindable var model = model
        return Table(of: MTPEntry.self, selection: $model.selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name, comparator: .localizedStandard) { entry in
                Label {
                    Text(entry.name)
                } icon: {
                    Image(systemName: entry.isFolder ? "folder.fill" : iconName(for: entry.name))
                        .foregroundStyle(entry.isFolder ? Color.accentColor : Color.secondary)
                }
            }
            .width(min: 200)
            TableColumn("Last Modified", value: \.modifiedForSorting) { entry in
                Text(Format.date(entry.modified)).foregroundStyle(.secondary)
            }
            .width(min: 140, ideal: 170)
            TableColumn("Size", value: \.size) { entry in
                Text(entry.isFolder ? "--" : Format.size(entry.size))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100)
        } rows: {
            ForEach(sortedEntries) { entry in
                TableRow(entry)
                    .itemProvider { dragProvider(for: entry) }
            }
        }
        .alternatingRowBackgrounds()
        .contextMenu(forSelectionType: MTPEntry.ID.self) { ids in
            let items = model.entries.filter { ids.contains($0.id) }
            if items.count == 1, items[0].isFolder {
                Button("Open") { model.open(items[0]) }
            }
            if !items.isEmpty {
                Button(items.count == 1 ? "Copy to Mac…" : "Copy \(items.count) Items to Mac…") {
                    model.selection = ids
                    model.downloadSelection()
                }
            }
            if items.count == 1 {
                Button("Rename…") { model.renaming = items[0] }
            }
            if !items.isEmpty {
                Divider()
                Button("Delete", role: .destructive) {
                    model.selection = ids
                    model.deleteSelection()
                }
            }
            if items.isEmpty {
                Button("New Folder") { model.newFolder() }
            }
        } primaryAction: { ids in
            if ids.count == 1, let entry = model.entries.first(where: { $0.id == ids.first }) {
                model.open(entry)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.upload(urls)
            return true
        }
        .overlay {
            if model.entries.isEmpty && !model.isLoading {
                Text("Drag files here to copy them to the device")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Drag out to Finder: the file is pulled from the device when Finder asks
    /// for it, so a drag of a large file costs nothing until it is dropped.
    private func dragProvider(for entry: MTPEntry) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = entry.name
        let session = model
        provider.registerFileRepresentation(forTypeIdentifier: UTType.item.identifier,
                                            fileOptions: [], visibility: .all) { completion in
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("AndroidFT-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            Task { @MainActor in
                session.download([entry], to: dir)
                // download() runs its own Task; wait for it to finish before handing over the URL.
                while session.transfer != nil { try? await Task.sleep(for: .milliseconds(100)) }
                let url = dir.appendingPathComponent(entry.name)
                let ok = FileManager.default.fileExists(atPath: url.path)
                completion(ok ? url : nil, false, ok ? nil : MTPError.copyFailed(entry.name))
            }
            return nil
        }
        return provider
    }

    private func iconName(for name: String) -> String {
        guard let type = UTType(filenameExtension: (name as NSString).pathExtension) else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .movie) { return "film" }
        if type.conforms(to: .audio) { return "music.note" }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { model.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!model.canGoBack).help("Back")
            Button { model.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!model.canGoForward).help("Forward")
            Button { model.goUp() } label: { Image(systemName: "arrow.up") }
                .disabled(!model.canGoUp).help("Enclosing folder")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { model.newFolder() } label: { Label("New Folder", systemImage: "folder.badge.plus") }
                .help("New Folder")
            Button { model.uploadViaPanel() } label: { Label("Copy to Device", systemImage: "square.and.arrow.down.on.square") }
                .help("Copy files from this Mac to the device")
            Button { model.downloadSelection() } label: { Label("Copy to Mac", systemImage: "square.and.arrow.up.on.square") }
                .disabled(model.selection.isEmpty).help("Copy the selected items to this Mac")
            Button { model.deleteSelection() } label: { Label("Delete", systemImage: "trash") }
                .disabled(model.selection.isEmpty).help("Delete")
            Button { model.reload() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                .help("Refresh")
        }
    }
}
