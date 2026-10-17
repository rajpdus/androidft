import XCTest
@testable import AndroidFT

/// Background-behaviour scenarios against a real phone: sustained transfers,
/// cancellation, device contention and recovery, the AppModel's own transfer
/// path, and a large-folder listing. All skip when no device is attached.
final class ScenarioTests: XCTestCase {
    private func openSession() throws -> MTPSession {
        let raws = MTPSession.detect()
        try XCTSkipIf(raws.isEmpty, "No MTP device attached")
        return try MTPSession(raw: raws[0])
    }

    private func randomFile(megabytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aft-\(UUID().uuidString).bin")
        let handle = try { try Data().write(to: url); return try FileHandle(forWritingTo: url) }()
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<megabytes {
            handle.write(Data((0..<1_048_576).map { _ in UInt8.random(in: 0...255, using: &rng) }))
        }
        try handle.close()
        return url
    }

    // 1. Sustained transfer: 48 MiB up, progress monotonic, 48 MiB down, bytes identical.
    func testLargeTransferRoundTripWithProgress() throws {
        let session = try openSession()
        let storage = try session.storages()[0]
        let folder = try session.createFolder(named: "AFT-scn-\(Int(Date().timeIntervalSince1970))", storage: storage.id, parent: nil)
        defer { try? session.delete(folder) }

        let local = try randomFile(megabytes: 48)
        defer { try? FileManager.default.removeItem(at: local) }
        var last: UInt64 = 0, calls = 0, monotonic = true
        let t0 = Date()
        let up = try session.upload(local, name: "big.bin", storage: storage.id, parent: folder.id) { sent, total in
            calls += 1; if sent < last { monotonic = false }; last = sent; return false
        }
        let upSecs = Date().timeIntervalSince(t0)
        XCTAssertTrue(monotonic); XCTAssertGreaterThan(calls, 5)
        XCTAssertEqual(up.size, 48 * 1_048_576)
        print(String(format: "Upload 48 MiB: %.1f s (%.1f MB/s), %d progress callbacks", upSecs, 48 / upSecs, calls))

        let back = local.appendingPathExtension("back")
        defer { try? FileManager.default.removeItem(at: back) }
        let t1 = Date()
        try session.download(up, to: back) { _, _ in false }
        let downSecs = Date().timeIntervalSince(t1)
        print(String(format: "Download 48 MiB: %.1f s (%.1f MB/s)", downSecs, 48 / downSecs))
        XCTAssertEqual(try Data(contentsOf: back), try Data(contentsOf: local))
    }

    // 2. Cancel: the file in flight completes (aborting mid-file wedges the phone's
    //    MTP service), the remaining files are skipped, and the device stays usable.
    @MainActor
    func testCancelFinishesCurrentFileAndSkipsRest() async throws {
        try XCTSkipIf(MTPSession.detect().isEmpty, "No MTP device attached")
        let model = AppModel()
        model.start()
        try await waitUntil("connected") { model.state == .connected && !model.entries.isEmpty }
        let session = try XCTUnwrap(model.sessionForTesting)
        let storage = try XCTUnwrap(model.selectedStorageID)
        let folder = try session.createFolder(named: "AFT-cancel-\(Int(Date().timeIntervalSince1970))", storage: storage, parent: nil)
        defer { try? session.delete(folder) }
        let f1 = try randomFile(megabytes: 24), f2 = try randomFile(megabytes: 2)
        defer { try? FileManager.default.removeItem(at: f1); try? FileManager.default.removeItem(at: f2) }
        let e1 = try session.upload(f1, name: "first.bin", storage: storage, parent: folder.id) { _, _ in false }
        let e2 = try session.upload(f2, name: "second.bin", storage: storage, parent: folder.id) { _, _ in false }

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("AFT-cancel-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: out) }
        model.download([e1, e2], to: out)
        try await waitUntil("4 MiB in flight") { (model.transfer?.bytesInProgress ?? 0) > 4 * 1_048_576 }
        model.cancelTransfer()
        XCTAssertEqual(model.transfer?.detail, "Finishing the current file, then stopping")
        try await waitUntil("transfer ended") { model.transfer == nil }

        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("first.bin")), try Data(contentsOf: f1), "file in flight completes intact")
        XCTAssertFalse(FileManager.default.fileExists(atPath: out.appendingPathComponent("second.bin").path), "later files are skipped")
        XCTAssertNil(model.alert)
        XCTAssertEqual(try session.list(storage: storage, parent: folder.id).count, 2, "device still answers after cancel")
    }

    // 3. Contention: a second client cannot open the device while we hold it; after we
    //    release it, a new open succeeds (this is what the retry loop relies on).
    func testDeviceContentionAndRecovery() throws {
        var first: MTPSession? = try openSession()
        _ = try first!.storages()
        let raws = MTPSession.detect()
        XCTAssertFalse(raws.isEmpty, "detection must still list the device while it is open")
        XCTAssertThrowsError(try MTPSession(raw: raws[0]), "second open must fail while the interface is claimed")

        first = nil   // releases the device
        let second = try MTPSession(raw: MTPSession.detect()[0])
        XCTAssertFalse(try second.storages().isEmpty)
    }

    // 4. AppModel's real background path: connect, navigate, upload a folder tree,
    //    download it back, compare, with the Transfer progress object driving state.
    @MainActor
    func testAppModelUploadAndDownloadFolderTree() async throws {
        try XCTSkipIf(MTPSession.detect().isEmpty, "No MTP device attached")
        let model = AppModel()
        model.start()
        try await waitUntil("connected") { model.state == .connected && !model.entries.isEmpty }

        // Build a local tree: dir/{a.bin, sub/b.bin}
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AFT-tree-\(Int(Date().timeIntervalSince1970))")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("sub"), withIntermediateDirectories: true)
        let a = Data((0..<300_000).map { _ in UInt8.random(in: 0...255) })
        let b = Data((0..<120_000).map { _ in UInt8.random(in: 0...255) })
        try a.write(to: root.appendingPathComponent("a.bin"))
        try b.write(to: root.appendingPathComponent("sub/b.bin"))
        defer { try? FileManager.default.removeItem(at: root) }

        model.upload([root])
        XCTAssertNotNil(model.transfer)
        try await waitUntil("upload finished") { model.transfer == nil }
        try await waitUntil("listing refreshed") { !model.isLoading && model.entries.contains { $0.name == root.lastPathComponent } }
        let remote = model.entries.first { $0.name == root.lastPathComponent }!
        XCTAssertTrue(remote.isFolder)

        model.open(remote)
        try await waitUntil("inside folder") { !model.isLoading && model.entries.contains { $0.name == "a.bin" } && model.entries.contains { $0.name == "sub" } }
        XCTAssertEqual(model.path.last?.name, root.lastPathComponent)
        XCTAssertEqual(model.entries.first { $0.name == "a.bin" }?.size, UInt64(a.count))

        model.goUp()
        try await waitUntil("back at root") { !model.isLoading && model.path.isEmpty }

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("AFT-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: out) }
        model.download([remote], to: out)
        try await waitUntil("download finished") { model.transfer == nil }
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("\(root.lastPathComponent)/a.bin")), a)
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("\(root.lastPathComponent)/sub/b.bin")), b)
        XCTAssertNil(model.alert, "no error alert expected: \(model.alert?.title ?? "")")

        // Clean up on the device through the wrapper (deleteSelection shows a modal).
        let session = try openSessionAfter(model)
        try session.delete(remote)
    }

    // 5. Large folder listing time (the phone's Download folder, hundreds of items).
    func testLargeFolderListingTime() throws {
        let session = try openSession()
        let storage = try session.storages()[0]
        let root = try session.list(storage: storage.id, parent: nil)
        guard let download = root.first(where: { $0.name == "Download" && $0.isFolder }) else { throw XCTSkip("no Download folder") }
        let t0 = Date()
        let items = try session.list(storage: storage.id, parent: download.id)
        let secs = Date().timeIntervalSince(t0)
        print(String(format: "Listed Download: %d items in %.2f s (%.1f ms/item)", items.count, secs, secs * 1000 / Double(max(items.count, 1))))
        XCTAssertFalse(items.isEmpty)
    }

    // MARK: helpers

    @MainActor
    private func waitUntil(_ what: String, timeout: TimeInterval = 90, _ cond: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !cond() {
            if Date() > deadline { XCTFail("timed out waiting for \(what)"); throw XCTSkip("timeout") }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    /// The model owns the device; drop it, wait for release, then open our own session.
    @MainActor
    private func openSessionAfter(_ model: AppModel) throws -> MTPSession {
        // AppModel keeps its session alive while connected. Opening a second session
        // would be refused (see testDeviceContentionAndRecovery), so reuse the model's.
        return try XCTUnwrap(model.sessionForTesting)
    }
}
