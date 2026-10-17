import Foundation
import CMTP

/// Thin Swift wrapper over the ~25 libmtp calls the original app uses.
///
/// libmtp is not thread-safe, so every call goes through one serial queue
/// (`MTPSession.queue`). The original app did the same with a pthread mutex
/// inside `MTPRepository`. Callers use the async `run` helper.
final class MTPSession {
    static let queue = DispatchQueue(label: "com.altslate.androidft.mtp", qos: .userInitiated)

    private static let initialize: Void = { LIBMTP_Init() }()

    private var device: UnsafeMutablePointer<LIBMTP_mtpdevice_t>
    let info: MTPDeviceInfo

    /// Hop onto the libmtp queue and run a blocking libmtp operation.
    static func run<T>(_ body: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            queue.async { cont.resume(with: Result { try body() }) }
        }
    }

    // MARK: Detection / open

    /// Enumerate attached raw MTP devices. Must be called on `queue`.
    static func detect() -> [LIBMTP_raw_device_t] {
        _ = initialize
        var raw: UnsafeMutablePointer<LIBMTP_raw_device_t>? = nil
        var count: Int32 = 0
        let err = LIBMTP_Detect_Raw_Devices(&raw, &count)
        guard err == LIBMTP_ERROR_NONE, let raw, count > 0 else { return [] }
        defer { free(raw) }
        return (0..<Int(count)).map { raw[$0] }
    }

    /// Open the first attached device. Must be called on `queue`.
    /// Mirrors `MTPRepository::mtpOpenDevice`: uncached open (upstream libmtp has no
    /// `Set_Device_Timeout`), plus a one-time 2 s retry for Samsung devices that are slow to switch to MTP.
    init(raw rawDevice: LIBMTP_raw_device_t) throws {
        _ = MTPSession.initialize
        var raw = rawDevice
        var opened = LIBMTP_Open_Raw_Device_Uncached(&raw)
        if opened == nil, raw.device_entry.vendor_id == 0x04e8 {
            sleep(2)
            opened = LIBMTP_Open_Raw_Device_Uncached(&raw)
        }
        guard let opened else { throw MTPError.cannotConnect }
        device = opened
        info = MTPDeviceInfo(
            id: MTPDeviceID(vendorID: raw.device_entry.vendor_id,
                            productID: raw.device_entry.product_id,
                            busLocation: raw.bus_location,
                            deviceNumber: raw.devnum),
            manufacturer: MTPSession.takeString(LIBMTP_Get_Manufacturername(opened)),
            model: MTPSession.takeString(LIBMTP_Get_Modelname(opened)),
            serialNumber: MTPSession.takeString(LIBMTP_Get_Serialnumber(opened)),
            version: MTPSession.takeString(LIBMTP_Get_Deviceversion(opened)))
    }

    deinit {
        LIBMTP_Release_Device(device)
    }

    // MARK: Storages

    /// Storage list. An empty list while the device is attached means the phone
    /// is locked or still in "charging only" mode, which the original app reports
    /// as "Can't access device storage".
    func storages() throws -> [MTPStorage] {
        LIBMTP_Clear_Errorstack(device)
        let rc = LIBMTP_Get_Storage(device, Int32(LIBMTP_STORAGE_SORTBY_NOTSORTED))
        var result: [MTPStorage] = []
        var node = device.pointee.storage
        while let s = node {
            let desc = s.pointee.StorageDescription.map { String(cString: $0) } ?? ""
            let vol = s.pointee.VolumeIdentifier.map { String(cString: $0) } ?? ""
            let name = desc.isEmpty ? (vol.isEmpty ? "Storage \(s.pointee.id)" : vol) : desc
            result.append(MTPStorage(id: s.pointee.id, name: name,
                                     capacity: s.pointee.MaxCapacity,
                                     freeSpace: s.pointee.FreeSpaceInBytes))
            node = s.pointee.next
        }
        if rc != 0 || result.isEmpty {
            clearErrors()
            throw MTPError.storageLocked
        }
        return result
    }

    // MARK: Listing

    func list(storage: UInt32, parent: UInt32?) throws -> [MTPEntry] {
        LIBMTP_Clear_Errorstack(device)
        let parentID = parent ?? UInt32(LIBMTP_FILES_AND_FOLDERS_ROOT)
        var node = LIBMTP_Get_Files_And_Folders(device, storage, parentID)
        if node == nil, let text = popErrors() {
            throw MTPError.communication(text)
        }
        var entries: [MTPEntry] = []
        while let f = node {
            let isFolder = f.pointee.filetype == LIBMTP_FILETYPE_FOLDER
            entries.append(MTPEntry(
                id: f.pointee.item_id,
                parentID: f.pointee.parent_id,
                storageID: f.pointee.storage_id,
                name: f.pointee.filename.map { String(cString: $0) } ?? "",
                size: isFolder ? 0 : f.pointee.filesize,
                modified: f.pointee.modificationdate > 0
                    ? Date(timeIntervalSince1970: TimeInterval(f.pointee.modificationdate)) : nil,
                isFolder: isFolder))
            node = f.pointee.next
            LIBMTP_destroy_file_t(f)
        }
        return entries
    }

    // MARK: Transfers

    /// Download one file to `destination`. `progress` receives (sent, total) and
    /// returns true to cancel.
    func download(_ entry: MTPEntry, to destination: URL,
                  progress: @escaping (UInt64, UInt64) -> Bool) throws {
        LIBMTP_Clear_Errorstack(device)
        let box = ProgressBox(progress)
        let rc = withExtendedLifetime(box) {
            LIBMTP_Get_File_To_File(device, entry.id, destination.path,
                                    progressTrampoline, Unmanaged.passUnretained(box).toOpaque())
        }
        if rc != 0 {
            if box.cancelled {
                try? FileManager.default.removeItem(at: destination)
                throw MTPError.cancelled
            }
            clearErrors()
            throw MTPError.copyFailed(entry.name)
        }
        if let date = entry.modified {
            try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: destination.path)
        }
    }

    /// Upload a local file into `parent` (nil = storage root). Returns the new entry.
    func upload(_ source: URL, name: String, storage: UInt32, parent: UInt32?,
                progress: @escaping (UInt64, UInt64) -> Bool) throws -> MTPEntry {
        LIBMTP_Clear_Errorstack(device)
        let attrs = try FileManager.default.attributesOfItem(atPath: source.path)
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        let modified = attrs[.modificationDate] as? Date

        guard let file = LIBMTP_new_file_t() else { throw MTPError.copyFailed(name) }
        defer { LIBMTP_destroy_file_t(file) }
        file.pointee.filename = strdup(name)
        file.pointee.filesize = size
        file.pointee.parent_id = parent ?? UInt32(LIBMTP_FILES_AND_FOLDERS_ROOT)
        file.pointee.storage_id = storage
        file.pointee.filetype = MTPSession.fileType(forExtension: source.pathExtension)
        if let modified { file.pointee.modificationdate = time_t(modified.timeIntervalSince1970) }

        let box = ProgressBox(progress)
        let rc = withExtendedLifetime(box) {
            LIBMTP_Send_File_From_File(device, source.path, file,
                                       progressTrampoline, Unmanaged.passUnretained(box).toOpaque())
        }
        if rc != 0 {
            clearErrors()
            throw box.cancelled ? MTPError.cancelled : MTPError.copyFailed(name)
        }
        return MTPEntry(id: file.pointee.item_id, parentID: parent ?? 0, storageID: storage,
                        name: name, size: size, modified: modified, isFolder: false)
    }

    // MARK: Folder / delete / rename

    func createFolder(named name: String, storage: UInt32, parent: UInt32?) throws -> MTPEntry {
        LIBMTP_Clear_Errorstack(device)
        let cName = strdup(name)
        defer { free(cName) }
        let newID = LIBMTP_Create_Folder(device, cName, parent ?? UInt32(LIBMTP_FILES_AND_FOLDERS_ROOT), storage)
        guard newID != 0 else {
            clearErrors()
            throw MTPError.createFolderFailed
        }
        return MTPEntry(id: newID, parentID: parent ?? 0, storageID: storage,
                        name: name, size: 0, modified: Date(), isFolder: true)
    }

    /// Delete an entry. Folders are emptied first because most devices refuse
    /// to delete a non-empty folder.
    func delete(_ entry: MTPEntry) throws {
        if entry.isFolder {
            for child in try list(storage: entry.storageID, parent: entry.id) {
                try delete(child)
            }
        }
        LIBMTP_Clear_Errorstack(device)
        if LIBMTP_Delete_Object(device, entry.id) != 0 {
            clearErrors()
            throw MTPError.deleteFailed(entry.name)
        }
    }

    func rename(_ entry: MTPEntry, to newName: String) throws {
        LIBMTP_Clear_Errorstack(device)
        let rc: Int32
        if entry.isFolder {
            guard let folder = LIBMTP_new_folder_t() else { throw MTPError.renameFailed(isFolder: true) }
            defer { LIBMTP_destroy_folder_t(folder) }
            folder.pointee.folder_id = entry.id
            folder.pointee.name = strdup(entry.name)
            rc = LIBMTP_Set_Folder_Name(device, folder, newName)
        } else {
            guard let file = LIBMTP_new_file_t() else { throw MTPError.renameFailed(isFolder: false) }
            defer { LIBMTP_destroy_file_t(file) }
            file.pointee.item_id = entry.id
            file.pointee.filename = strdup(entry.name)
            rc = LIBMTP_Set_File_Name(device, file, newName)
        }
        if rc != 0 {
            clearErrors()
            throw MTPError.renameFailed(isFolder: entry.isFolder)
        }
    }

    // MARK: Helpers

    private func popErrors() -> String? {
        var texts: [String] = []
        var node = LIBMTP_Get_Errorstack(device)
        while let e = node {
            if let t = e.pointee.error_text { texts.append(String(cString: t)) }
            node = e.pointee.next
        }
        LIBMTP_Clear_Errorstack(device)
        return texts.isEmpty ? nil : texts.joined(separator: "\n")
    }

    private func clearErrors() {
        LIBMTP_Dump_Errorstack(device)
        LIBMTP_Clear_Errorstack(device)
    }

    private static func takeString(_ p: UnsafeMutablePointer<CChar>?) -> String {
        guard let p else { return "" }
        defer { free(p) }
        return String(cString: p)
    }

    /// Minimal extension → MTP type map so phones index uploads correctly
    /// (the original had a similar `mtpFindFileType`).
    static func fileType(forExtension ext: String) -> LIBMTP_filetype_t {
        switch ext.lowercased() {
        case "jpg", "jpeg": return LIBMTP_FILETYPE_JPEG
        case "png": return LIBMTP_FILETYPE_PNG
        case "gif": return LIBMTP_FILETYPE_GIF
        case "bmp": return LIBMTP_FILETYPE_BMP
        case "tif", "tiff": return LIBMTP_FILETYPE_TIFF
        case "mp3": return LIBMTP_FILETYPE_MP3
        case "m4a": return LIBMTP_FILETYPE_M4A
        case "aac": return LIBMTP_FILETYPE_AAC
        case "wav": return LIBMTP_FILETYPE_WAV
        case "ogg": return LIBMTP_FILETYPE_OGG
        case "flac": return LIBMTP_FILETYPE_FLAC
        case "mp4", "m4v", "3gp": return LIBMTP_FILETYPE_MP4
        case "mov": return LIBMTP_FILETYPE_QT
        case "avi": return LIBMTP_FILETYPE_AVI
        case "wmv": return LIBMTP_FILETYPE_WMV
        case "txt": return LIBMTP_FILETYPE_TEXT
        case "html", "htm": return LIBMTP_FILETYPE_HTML
        case "pdf", "doc", "docx": return LIBMTP_FILETYPE_DOC
        case "xls", "xlsx": return LIBMTP_FILETYPE_XLS
        case "ppt", "pptx": return LIBMTP_FILETYPE_PPT
        case "vcf": return LIBMTP_FILETYPE_VCARD3
        case "ics": return LIBMTP_FILETYPE_VCALENDAR2
        default: return LIBMTP_FILETYPE_UNKNOWN
        }
    }
}

/// Carries the Swift progress closure across the C callback boundary.
private final class ProgressBox {
    let callback: (UInt64, UInt64) -> Bool
    var cancelled = false
    init(_ callback: @escaping (UInt64, UInt64) -> Bool) { self.callback = callback }
}

private let progressTrampoline: LIBMTP_progressfunc_t = { sent, total, data in
    guard let data else { return 0 }
    let box = Unmanaged<ProgressBox>.fromOpaque(data).takeUnretainedValue()
    if box.callback(sent, total) {
        box.cancelled = true
        return 1
    }
    return 0
}
