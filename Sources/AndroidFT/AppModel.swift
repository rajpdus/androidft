import AppKit
import Foundation
import Observation

enum ConnectionState: Equatable {
    case noDevice
    case connecting
    case locked          // attached, but storage not accessible (locked / charge-only)
    case connected
}

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@Observable @MainActor
final class AppModel {
    var state: ConnectionState = .noDevice
    var deviceInfo: MTPDeviceInfo?
    var storages: [MTPStorage] = []
    var selectedStorageID: UInt32? {
        didSet { if oldValue != selectedStorageID, selectedStorageID != nil { history.removeAll(); forward.removeAll(); path = []; reload() } }
    }
    var path: [MTPEntry] = []          // breadcrumb from the storage root
    var entries: [MTPEntry] = []
    var selection = Set<UInt32>()
    var isLoading = false
    var transfer: Transfer?
    var alert: AlertInfo?
    var renaming: MTPEntry?

    private var history: [[MTPEntry]] = []
    private var forward: [[MTPEntry]] = []
    private var session: MTPSession?
    private var watcher: DeviceWatcher?
    private var retryTask: Task<Void, Never>?
    private var listingCache: [String: [MTPEntry]] = [:]

    var currentStorage: MTPStorage? { storages.first { $0.id == selectedStorageID } }
    var currentFolderID: UInt32? { path.last?.id }
    var canGoBack: Bool { !history.isEmpty }
    var canGoForward: Bool { !forward.isEmpty }
    var canGoUp: Bool { !path.isEmpty }
    var selectedEntries: [MTPEntry] { entries.filter { selection.contains($0.id) } }

    var statusText: String {
        let avail = currentStorage.map { ", \(Format.size($0.freeSpace)) available" } ?? ""
        if !selection.isEmpty { return "\(selection.count) of \(entries.count) selected\(avail)" }
        return entries.count == 1 ? "1 item\(avail)" : "\(entries.count) items\(avail)"
    }

    // MARK: Lifecycle

    func start() {
        guard watcher == nil else { return }
        watcher = DeviceWatcher { [weak self] in self?.refreshDevice() }
        refreshDevice()
    }

    /// Re-detect devices. Called at launch, on USB hot-plug, and by the retry loop
    /// while the phone is locked.
    func refreshDevice() {
        retryTask?.cancel()
        Task { await detectAndOpen() }
    }

    private func detectAndOpen() async {
        let raws = try? await MTPSession.run { MTPSession.detect() }
        guard let raws, let first = raws.first else {
            session = nil
            deviceInfo = nil
            storages = []
            entries = []
            path = []
            listingCache.removeAll()
            state = .noDevice
            return
        }
        if session == nil {
            state = .connecting
            do {
                let s = try await MTPSession.run { try MTPSession(raw: first) }
                session = s
                deviceInfo = s.info
            } catch {
                state = .locked
                scheduleRetry()
                return
            }
        }
        await loadStorages()
    }

    private func loadStorages() async {
        guard let session else { return }
        do {
            let list = try await MTPSession.run { try session.storages() }
            storages = list
            state = .connected
            if selectedStorageID == nil || !list.contains(where: { $0.id == selectedStorageID }) {
                selectedStorageID = list.first?.id   // triggers reload()
            } else {
                reload()
            }
        } catch {
            // Locked phone, or USB mode still "charging only": poll until it opens up,
            // the way the original kept retrying.
            state = .locked
            storages = []
            entries = []
            scheduleRetry()
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            // A failed open leaves a half-initialised handle; start fresh.
            if self?.state == .locked, self?.storages.isEmpty == true { self?.session = nil }
            await self?.detectAndOpen()
        }
    }

    // MARK: Navigation

    private func cacheKey(_ storage: UInt32, _ parent: UInt32?) -> String { "\(storage)/\(parent ?? 0)" }

    func reload(useCache: Bool = false) {
        guard let session, let storage = selectedStorageID else { return }
        let parent = currentFolderID
        if useCache, let cached = listingCache[cacheKey(storage, parent)] {
            entries = cached
            return
        }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let list = try await MTPSession.run { try session.list(storage: storage, parent: parent) }
                let sorted = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                listingCache[cacheKey(storage, parent)] = sorted
                // Ignore stale results if the user navigated away meanwhile.
                guard selectedStorageID == storage, currentFolderID == parent else { return }
                entries = sorted
                selection = selection.filter { id in sorted.contains { $0.id == id } }
            } catch {
                show(error)
                if (error as? MTPError) == .storageLocked { state = .locked; scheduleRetry() }
            }
        }
    }

    private func navigate(to newPath: [MTPEntry], recordHistory: Bool = true) {
        if recordHistory { history.append(path); forward.removeAll() }
        path = newPath
        selection = []
        reload(useCache: true)
        reload()
    }

    func open(_ entry: MTPEntry) {
        if entry.isFolder {
            navigate(to: path + [entry])
        } else {
            alert = AlertInfo(title: "Android File Transfer cannot open files",
                              message: "To open a file, move it to your computer first.")
        }
    }

    func openSelection() {
        let sel = selectedEntries
        switch sel.count {
        case 0: alert = AlertInfo(title: "No item selected to open", message: "Select a single item and try again.")
        case 1: open(sel[0])
        default: alert = AlertInfo(title: "Android File Transfer cannot open multiple items",
                                   message: "Select a single item and try again.")
        }
    }

    func goUp() { guard canGoUp else { return }; navigate(to: Array(path.dropLast())) }
    func goBack() {
        guard let prev = history.popLast() else { return }
        forward.append(path)
        navigate(to: prev, recordHistory: false)
    }
    func goForward() {
        guard let next = forward.popLast() else { return }
        history.append(path)
        navigate(to: next, recordHistory: false)
    }
    func jump(toDepth depth: Int) { navigate(to: Array(path.prefix(depth))) }

    // MARK: Folder / delete / rename

    func newFolder() {
        guard let session, let storage = selectedStorageID else { return }
        let parent = currentFolderID
        var name = "untitled folder"
        var n = 2
        while entries.contains(where: { $0.name == name }) { name = "untitled folder \(n)"; n += 1 }
        Task {
            do {
                let folder = try await MTPSession.run { try session.createFolder(named: name, storage: storage, parent: parent) }
                reload()
                selection = [folder.id]
                renaming = folder
            } catch { show(error) }
        }
    }

    func deleteSelection() {
        let items = selectedEntries
        guard !items.isEmpty, let session else { return }
        let confirm = NSAlert()
        confirm.messageText = "Are you sure you want to permanently delete the selected items?"
        confirm.informativeText = "You can't undo this action"
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: "Delete")
        confirm.addButton(withTitle: "Cancel")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        Task {
            for item in items {
                do { try await MTPSession.run { try session.delete(item) } }
                catch { show(error); break }
            }
            selection = []
            reload()
        }
    }

    func rename(_ entry: MTPEntry, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let session, !name.isEmpty, name != entry.name else { return }
        if entries.contains(where: { $0.name == name }) {
            show(MTPError.alreadyExists, title: entry.isFolder ? "Could not rename folder" : "Could not rename file")
            return
        }
        Task {
            do {
                try await MTPSession.run { try session.rename(entry, to: name) }
                reload()
            } catch { show(error) }
        }
    }

    // MARK: Transfers (device → Mac)

    /// Ask for a destination folder, then copy the selection there.
    func downloadSelection() {
        let items = selectedEntries
        guard !items.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Copy Here"
        panel.message = items.count == 1 ? "Choose where to copy \"\(items[0].name)\"" : "Choose where to copy \(items.count) items"
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        download(items, to: dir)
    }

    func download(_ items: [MTPEntry], to directory: URL) {
        guard let session, transfer == nil else { return }
        let job = Transfer(direction: .download, destinationName: directory.lastPathComponent)
        job.itemCount = items.count
        transfer = job
        Task {
            defer { transfer = nil }
            do {
                // Preflight: walk folders to know the total size (shows "Preparing to copy…").
                var plan: [(MTPEntry, URL)] = []
                var folders: [URL] = []
                for item in items {
                    try await collect(item, into: directory, session: session, files: &plan, folders: &folders)
                }
                job.bytesTotal = plan.reduce(0) { $0 + $1.0.size }
                job.preflightComplete = true

                var replaceAll = false
                for folder in folders {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                }
                for (entry, dest) in plan {
                    if job.cancelled { throw MTPError.cancelled }
                    if FileManager.default.fileExists(atPath: dest.path) && !replaceAll {
                        switch askReplace(name: entry.name) {
                        case .skip: job.bytesCompleted += entry.size; continue
                        case .replaceAll: replaceAll = true
                        case .replace: break
                        }
                    }
                    job.currentName = entry.name
                    job.bytesInProgress = 0
                    let tmp = dest.deletingLastPathComponent().appendingPathComponent(".\(entry.name).aft-part")
                    try await MTPSession.run {
                        try session.download(entry, to: tmp) { sent, _ in
                            Task { @MainActor in job.bytesInProgress = sent }
                            return job.cancelled
                        }
                    }
                    _ = try? FileManager.default.replaceItemAt(dest, withItemAt: tmp)
                    try? FileManager.default.removeItem(at: tmp)
                    job.bytesCompleted += entry.size
                    job.bytesInProgress = 0
                }
            } catch MTPError.cancelled {
            } catch { show(error) }
        }
    }

    private func collect(_ entry: MTPEntry, into dir: URL, session: MTPSession,
                         files: inout [(MTPEntry, URL)], folders: inout [URL]) async throws {
        let target = dir.appendingPathComponent(entry.name)
        if entry.isFolder {
            folders.append(target)
            let children = try await MTPSession.run { try session.list(storage: entry.storageID, parent: entry.id) }
            for child in children {
                try await collect(child, into: target, session: session, files: &files, folders: &folders)
            }
        } else {
            files.append((entry, target))
        }
    }

    // MARK: Transfers (Mac → device)

    func uploadViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Copy to Device"
        guard panel.runModal() == .OK else { return }
        upload(panel.urls)
    }

    /// Copy local files/folders into the current device folder.
    func upload(_ urls: [URL]) {
        guard let session, let storage = selectedStorageID, transfer == nil, !urls.isEmpty else { return }
        let parent = currentFolderID
        let destName = path.last?.name ?? currentStorage?.name ?? deviceInfo?.displayName ?? "device"
        let job = Transfer(direction: .upload, destinationName: destName)
        job.itemCount = urls.count
        transfer = job
        Task {
            defer { transfer = nil; reload() }
            do {
                // Preflight: total bytes of everything we are about to send.
                var total: UInt64 = 0
                for url in urls { total += localSize(url) }
                job.bytesTotal = total
                job.preflightComplete = true

                var replaceAll = false
                var existing = try await MTPSession.run { try session.list(storage: storage, parent: parent) }
                for url in urls {
                    if job.cancelled { throw MTPError.cancelled }
                    if let clash = existing.first(where: { $0.name == url.lastPathComponent }) {
                        if !replaceAll {
                            switch askReplace(name: clash.name) {
                            case .skip: job.bytesCompleted += localSize(url); continue
                            case .replaceAll: replaceAll = true
                            case .replace: break
                            }
                        }
                        try await MTPSession.run { try session.delete(clash) }
                        existing.removeAll { $0.id == clash.id }
                    }
                    try await send(url, storage: storage, parent: parent, session: session, job: job)
                }
            } catch MTPError.cancelled {
            } catch { show(error) }
        }
    }

    private func send(_ url: URL, storage: UInt32, parent: UInt32?, session: MTPSession, job: Transfer) async throws {
        if job.cancelled { throw MTPError.cancelled }
        let name = url.lastPathComponent
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if isDir.boolValue {
            let folder = try await MTPSession.run { try session.createFolder(named: name, storage: storage, parent: parent) }
            let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil,
                                                                         options: [.skipsHiddenFiles])) ?? []
            for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                try await send(child, storage: storage, parent: folder.id, session: session, job: job)
            }
        } else {
            job.currentName = name
            job.bytesInProgress = 0
            let sent = try await MTPSession.run {
                try session.upload(url, name: name, storage: storage, parent: parent) { sent, _ in
                    Task { @MainActor in job.bytesInProgress = sent }
                    return job.cancelled
                }
            }
            job.bytesCompleted += sent.size
            job.bytesInProgress = 0
        }
    }

    private func localSize(_ url: URL) -> UInt64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil,
                                                                         options: [.skipsHiddenFiles])) ?? []
            return children.reduce(0) { $0 + localSize($1) }
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value
        return size ?? 0
    }

    func cancelTransfer() { transfer?.cancelled = true }

    // MARK: Alerts

    private func askReplace(name: String) -> ReplaceChoice {
        let a = NSAlert()
        a.messageText = "An item named \"\(name)\" already exists in this folder."
        a.informativeText = "Would you like to replace the existing item with the one being copied?"
        a.addButton(withTitle: "Replace")
        a.addButton(withTitle: "Replace All")
        a.addButton(withTitle: "Skip")
        switch a.runModal() {
        case .alertFirstButtonReturn: return .replace
        case .alertSecondButtonReturn: return .replaceAll
        default: return .skip
        }
    }

    private func show(_ error: Error, title: String? = nil) {
        let mtp = error as? MTPError
        alert = AlertInfo(title: title ?? mtp?.errorDescription ?? "Could not communicate with device",
                          message: mtp?.recoverySuggestion ?? error.localizedDescription)
    }
}
