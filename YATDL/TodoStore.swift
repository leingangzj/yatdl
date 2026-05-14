// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Foundation
import Combine

// Shared between the GUI panel and the file-watcher reload path.
enum DisplayMode: String, Codable {
    case dropFromMenubar
    case slideFromRight
}

// Central in-process store for the GUI. Owns the published state that
// SwiftUI views observe and is the single writer of the shared data file.
// The CLI writes the same file; FileWatcher triggers a reload when that happens.
final class TodoStore: ObservableObject {
    @Published var lists:          [TodoList] = []
    @Published var selectedListID: UUID?
    @Published var displayMode:    DisplayMode = .dropFromMenubar
    @Published var isPinned:       Bool = false

    let saveURL: URL
    private var fileWatcher: FileWatcher?
    private var lastSaveDate: Date = .distantPast

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("YATDL")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("data.json")

        load()

        if lists.isEmpty {
            let list = TodoList(name: "Personal")
            lists          = [list]
            selectedListID = list.id
        }

        startWatching()
    }

    func save() {
        lastSaveDate = Date()
        let payload = Payload(lists: lists, selectedListID: selectedListID, displayMode: displayMode)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }

    func load() {
        guard let data    = try? Data(contentsOf: saveURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        lists          = payload.lists
        selectedListID = payload.selectedListID
        displayMode    = payload.displayMode
    }

    // Skips reloads triggered by our own writes using a 250 ms grace window.
    // Without this, every GUI save would bounce back through the file watcher
    // and clobber any in-progress text field edits.
    private func startWatching() {
        fileWatcher = FileWatcher(url: saveURL)
        fileWatcher?.onChange = { [weak self] in
            guard let self else { return }
            guard Date().timeIntervalSince(self.lastSaveDate) > 0.25 else { return }
            self.load()
        }
        fileWatcher?.start()
    }

    struct Payload: Codable {
        var lists:          [TodoList]
        var selectedListID: UUID?
        var displayMode:    DisplayMode
    }
}
