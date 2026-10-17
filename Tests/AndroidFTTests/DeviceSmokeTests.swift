import XCTest
@testable import AndroidFT

/// End-to-end check against a real phone in "File transfer" mode. Skips when no
/// MTP device is attached. Exercises every libmtp call the app uses.
final class DeviceSmokeTests: XCTestCase {
    func testRoundTripAgainstAttachedDevice() throws {
        let raws = MTPSession.detect()
        try XCTSkipIf(raws.isEmpty, "No MTP device attached")
        let session = try MTPSession(raw: raws[0])
        print("Device:", session.info.displayName, session.info.serialNumber)

        let storages = try session.storages()
        XCTAssertFalse(storages.isEmpty)
        let storage = storages[0]
        print("Storage:", storage.name, Format.size(storage.freeSpace), "free of", Format.size(storage.capacity))

        let root = try session.list(storage: storage.id, parent: nil)
        XCTAssertFalse(root.isEmpty, "root listing should not be empty")
        print("Root:", root.map(\.name).sorted().joined(separator: ", "))

        // Create a scratch folder.
        let folderName = "AFT-smoke-\(Int(Date().timeIntervalSince1970))"
        let folder = try session.createFolder(named: folderName, storage: storage.id, parent: nil)
        XCTAssertNotEqual(folder.id, 0)
        defer { try? session.delete(folder) }
        XCTAssertTrue(try session.list(storage: storage.id, parent: nil).contains { $0.name == folderName })

        // Upload 1 MiB of random bytes.
        let payload = Data((0..<1_048_576).map { _ in UInt8.random(in: 0...255) })
        let local = FileManager.default.temporaryDirectory.appendingPathComponent("aft-smoke-\(UUID().uuidString).bin")
        try payload.write(to: local)
        defer { try? FileManager.default.removeItem(at: local) }
        var progressCalls = 0
        let uploaded = try session.upload(local, name: "payload.bin", storage: storage.id, parent: folder.id) { _, _ in
            progressCalls += 1; return false
        }
        XCTAssertEqual(uploaded.size, UInt64(payload.count))
        XCTAssertGreaterThan(progressCalls, 0, "progress callback should fire")

        var children = try session.list(storage: storage.id, parent: folder.id)
        XCTAssertEqual(children.map(\.name), ["payload.bin"])
        XCTAssertEqual(children[0].size, UInt64(payload.count))

        // Download it back and compare.
        let back = local.appendingPathExtension("back")
        try session.download(children[0], to: back) { _, _ in false }
        defer { try? FileManager.default.removeItem(at: back) }
        XCTAssertEqual(try Data(contentsOf: back), payload, "downloaded bytes must match")

        // Rename, then verify.
        try session.rename(children[0], to: "renamed.bin")
        children = try session.list(storage: storage.id, parent: folder.id)
        XCTAssertEqual(children.map(\.name), ["renamed.bin"])

        // Delete the folder (recursively) and verify it is gone.
        try session.delete(folder)
        XCTAssertFalse(try session.list(storage: storage.id, parent: nil).contains { $0.name == folderName })
    }
}
