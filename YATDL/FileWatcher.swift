// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Foundation

// Watches a single file for writes using a kqueue-backed DispatchSource.
// Cheaper than FSEvents for a one-file case; no polling, no timers.
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let url: URL
    var onChange: (() -> Void)?

    init(url: URL) {
        self.url = url
    }

    func start() {
        // O_EVTONLY lets the kernel track the descriptor without preventing unmount
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        src.setEventHandler { [weak self] in self?.onChange?() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
