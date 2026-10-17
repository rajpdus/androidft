import Foundation

/// Identifies one attached MTP device (vendor/product plus USB bus position).
/// Mirrors the original app's `DeviceID` (vendorID, productID, locationID).
struct MTPDeviceID: Hashable, Sendable {
    let vendorID: UInt16
    let productID: UInt16
    let busLocation: UInt32
    let deviceNumber: UInt8
}

struct MTPDeviceInfo: Hashable, Sendable {
    let id: MTPDeviceID
    let manufacturer: String
    let model: String
    let serialNumber: String
    let version: String

    var displayName: String {
        let name = [manufacturer, model].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Android device" : name
    }
}

struct MTPStorage: Identifiable, Hashable, Sendable {
    let id: UInt32
    let name: String
    let capacity: UInt64
    let freeSpace: UInt64
}

struct MTPEntry: Identifiable, Hashable, Sendable {
    let id: UInt32
    let parentID: UInt32
    let storageID: UInt32
    var name: String
    let size: UInt64
    let modified: Date?
    let isFolder: Bool

    var modifiedForSorting: Date { modified ?? .distantPast }
}

/// Error texts are taken from the original app's Localizable.strings so the
/// replacement reads the same way to someone who used Android File Transfer.
enum MTPError: LocalizedError, Equatable {
    case noDevice
    case cannotConnect
    case storageLocked
    case communication(String)
    case copyFailed(String)
    case createFolderFailed
    case deleteFailed(String)
    case renameFailed(isFolder: Bool)
    case alreadyExists
    case notFound
    case invalidStorage
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noDevice: return "No Android device found"
        case .cannotConnect: return "Could not connect to device"
        case .storageLocked: return "Can't access device storage"
        case .communication: return "Could not communicate with device"
        case .copyFailed: return "Could not copy file"
        case .createFolderFailed: return "Could not create folder"
        case .deleteFailed: return "Error while deleting"
        case .renameFailed(let isFolder): return isFolder ? "Could not rename folder" : "Could not rename file"
        case .alreadyExists: return "A file or folder with that name already exists"
        case .notFound: return "No item exists with that name"
        case .invalidStorage: return "Could not find the selected storage."
        case .cancelled: return "Canceled"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noDevice: return "Please connect your Android device with a USB cable to get started."
        case .storageLocked: return "Make sure your device is unlocked and \"File Transfer\" or \"MTP\" mode is selected."
        case .cannotConnect, .createFolderFailed, .renameFailed: return "Try reconnecting or restarting your device."
        case .communication(let detail): return detail.isEmpty ? "Try reconnecting or restarting your device." : detail
        case .copyFailed(let name): return "Could not copy file \"\(name)\""
        case .deleteFailed(let name): return "Could not delete file or folder named \"\(name)\""
        default: return nil
        }
    }
}
