# Reverse-engineering notes: Android File Transfer 1.0.12 (Google, 2018)

Produced with REA 6.5.0 (`rea inspect-macho`, `inspect-native-dispatch-metadata`,
`decode-interface-builder`, and Ghidra 12.1.4 `analyze`/`function`). Raw outputs
are in `re/snapshots/` and `re/decomp/`; the ObjC class map is `re/objc-classes.md`.

## Architecture

```
Android File Transfer.app (x86_64, Cocoa, libstdc++)
├── ObjC UI layer
│   MTPViewerAppDelegate, MTPOutlineController (NSWindowController, NSOutlineView),
│   MTPOutlineNode (lazy tree node), CopyStatusViewController / StatusWindowController
│   (progress sheet), FirstRunWindowController, RecessedButtonMatrix (storage picker),
│   AgentRunner : BundleInstaller (copies the Agent to ~/Library and registers it as
│   a login item via LSSharedFileList), MTPDeviceID (vendor/product/location).
├── C++ repository layer (what the UI talks to)
│   MTPFactory::Init / GetConnectedDeviceIDs / CreateRepository
│   MTPRepository::Load, ListFolder, Lookup, MakeFolder, Delete, SetName, Send, Receive
│   Cache (per-storage path -> Resource map; List/Get/Set/Rename/Delete)
└── bundled libmtp.dylib + libusb.dylib (Google-patched libmtp: has
    LIBMTP_Set_Load_Cache_On_Demand, which upstream 1.1.23 lacks)

Helpers/Android File Transfer Agent.app (LSBackgroundOnly login item)
    HotPluggable (IOKit USB notifications) + DelayedProcessing (1 s debounce)
    -> launches the viewer or posts NSDistributedNotification
       "com.google.android.mtpviewer.createNewWindow" with the MTPDeviceID dict.
```

## Device detection and open (MTPFactory / MTPRepository::mtpOpenDevice)

- `MTPFactory::Init`: `LIBMTP_Init(); LIBMTP_Set_Load_Cache_On_Demand(1);`
- `GetConnectedDeviceIDs`: `LIBMTP_Detect_Raw_Devices`, copies vendor_id,
  product_id, bus_location into `DeviceID`. Error 5 (NO_DEVICE_ATTACHED) → none.
- `mtpOpenDevice`: re-detects, finds the raw device matching the DeviceID, then
  `LIBMTP_Open_Raw_Device_Uncached`. **Samsung quirk**: if open fails and the
  device is vendor 0x04E8 product 0x6860 (Galaxy in MTP mode) it sleeps 2 s and
  retries once. Then `LIBMTP_Set_Device_Timeout(dev, 20000)` (20 s) and creates
  one `Cache` per storage in `dev->storage`.
- `Load` is lazy: opens the device the first time any operation needs it, under
  a pthread mutex (all repository calls are serialised).

## Agent (hot-plug)

- `HotPluggable::Register` registers IOKit matching notifications for USB
  devices; `DeviceAdded` opens an IOUSBDeviceInterface, reads vendor/product/
  location, then polls `MTPFactory::IsMTPDevice(vid, pid)` up to 10 × 100 ms
  (the device re-enumerates when the user switches USB mode).
- `add_device_callback` → `DelayedProcessing deviceAdded:` which, for Samsung
  0x04E8/0x6860 only, waits until a full second has passed with no new add
  event before acting (`checkDevice:` reschedules otherwise). Everything else
  goes straight to `add_device_callback_real`.
- `add_device_callback_real`: if the viewer (`com.google.android.mtpviewer`) is
  not running, `NSWorkspace launchApplication:`; otherwise post the distributed
  notification so the running app opens a new window.
- `GetViewerPathOrDelete`: if the main app has been uninstalled, the Agent
  removes itself from login items, deletes its own bundle and exits.

## Browsing (MTPRepository::mtpListFolder)

- Per storage, a path-keyed `Cache` of `Resource {name, id, storageId, size,
  modificationdate, type, loaded}`. Listing a folder whose Resource is not yet
  `loaded` calls `LIBMTP_Get_Files_And_Folders(dev, storageId, parentId)` once,
  inserts every child into the cache (`AppendPath(parent, filename)`), destroys
  each `LIBMTP_file_t`, marks the folder loaded, then answers from the cache.
  Root uses parent id 0xFFFFFFFF (`LIBMTP_FILES_AND_FOLDERS_ROOT`).
- Folder detection: `filetype == LIBMTP_FILETYPE_FOLDER`; folders get size 0.
- Result codes (`Repository::Result`, mapped by `LocalizedInformativeTextForResult`):
  0 success, 1 generic ("Try reconnecting or restarting your device."),
  2 path not found, 3 device not initialised, 4 path already exists,
  5/6 invalid storage.

## Transfers

- `Send(storage, localPath, devicePath, cb, ctx)`: splits devicePath into
  parent + name, requires the parent to be a loaded folder, rejects names
  starting with ".", `stat`s the local file, then `mtpSendFile`:
  `LIBMTP_new_file_t`, filename = strdup(name), filesize, filetype from
  `mtpFindFileType(name)` (extension map), parent_id, storage_id,
  `LIBMTP_Send_File_From_File(dev, localPath, file, cb, ctx)`; on success the
  new item_id is stored in the cache with `time(NULL)` as modification date.
- `Receive` → `mtpGetFile` → `LIBMTP_Get_File_To_File(dev, id, localPath, cb, ctx)`.
- Progress callback (`progress()`): posts `setFileInProgressBytesCopied:` to the
  main thread; only polls `shouldCancel` while more than 15 MB (0xF00000)
  remain, so small tails always finish.
- UI strings: "Preparing to copy to …", "Copying N items to …",
  "%@ of %@ - About N minutes remaining", replace/replace-all/skip on conflict.

## Folder, delete, rename

- `MakeFolder`: if the path already exists and is a folder → success (idempotent);
  otherwise `LIBMTP_Create_Folder(dev, name, parentId, storageId)` (0 = failure).
  The parent id for the storage root is `0xFFFFFFFF` (the cache's root Resource id),
  not 0: a Pixel 3a answers parent 0 with PTP 0x2009 "Could not send object info".
  The same applies to `parent_id` on uploads.
- `Delete`: `LIBMTP_Delete_Object(dev, id)`; on failure dumps + clears the
  libmtp error stack. No recursion in the repository (UI deletes children first).
- `SetName`: refuses if target name exists (result 4). Folders →
  `LIBMTP_new_folder_t` + `LIBMTP_Set_Folder_Name`; files → `LIBMTP_new_file_t`
  + `LIBMTP_Set_File_Name`; then renames the cache entry.

## What the Swift rewrite keeps / changes

Keeps: uncached open, 20 s timeout, Samsung retry, root id 0xFFFFFFFF, the
progress-callback cancel contract, error wording, size/time formatting, the
replace/skip flow, delete-children-first, rename-conflict check.

Changes: hot-plug detection lives in the app (IOKit `IOUSBHostDevice`
notifications, 1 s debounce) instead of a login-item Agent; listing cache is
per (storage, parent) in `AppModel` and always refreshed after a cache hit;
links Homebrew libmtp 1.1.23 (no `Set_Load_Cache_On_Demand`; the uncached open
already gives on-demand loading).
