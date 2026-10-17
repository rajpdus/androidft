import Foundation
import IOKit
import IOKit.usb

/// Watches IOKit for USB devices appearing or disappearing and fires `onChange`
/// after a short quiet period. The original app's Agent did the same with
/// `HotPluggable` + `DelayedProcessing` (1 s debounce); here the main app owns it.
final class DeviceWatcher {
    private let port: IONotificationPortRef
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var pending: DispatchWorkItem?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, .main)
        let me = Unmanaged.passUnretained(self).toOpaque()
        // IOServiceAddMatchingNotification consumes one reference to the matching dict each time.
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification,
                                         IOServiceMatching("IOUSBHostDevice"),
                                         deviceCallback, me, &addedIterator)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification,
                                         IOServiceMatching("IOUSBHostDevice"),
                                         deviceCallback, me, &removedIterator)
        // Arm the notifications by draining the iterators once.
        DeviceWatcher.drain(addedIterator)
        DeviceWatcher.drain(removedIterator)
    }

    deinit {
        pending?.cancel()
        IOObjectRelease(addedIterator)
        IOObjectRelease(removedIterator)
        IONotificationPortDestroy(port)
    }

    fileprivate func deviceEvent(_ iterator: io_iterator_t) {
        DeviceWatcher.drain(iterator)
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private static func drain(_ iterator: io_iterator_t) {
        var object = IOIteratorNext(iterator)
        while object != 0 {
            IOObjectRelease(object)
            object = IOIteratorNext(iterator)
        }
    }
}

private let deviceCallback: IOServiceMatchingCallback = { refcon, iterator in
    guard let refcon else { return }
    Unmanaged<DeviceWatcher>.fromOpaque(refcon).takeUnretainedValue().deviceEvent(iterator)
}
