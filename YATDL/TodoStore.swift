// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Foundation
import Combine

enum DisplayMode: String, Codable {
    case dropFromMenubar
    case slideFromRight
}

final class TodoStore: ObservableObject {
    @Published var lists:               [TodoList] = []
    @Published var selectedListID:      UUID?
    @Published var displayMode:         DisplayMode = .dropFromMenubar
    @Published var isPinned:            Bool = false
    @Published var pendingEditItemID:   UUID? = nil
    @Published var pendingRenameListID: UUID? = nil

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
        let payload = Payload(lists: lists, selectedListID: selectedListID,
                              displayMode: displayMode, isPinned: isPinned)
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
        isPinned       = payload.isPinned
    }

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
        var isPinned:       Bool

        private enum CodingKeys: String, CodingKey {
            case lists, selectedListID, displayMode, isPinned
        }

        init(lists: [TodoList], selectedListID: UUID?, displayMode: DisplayMode, isPinned: Bool) {
            self.lists          = lists
            self.selectedListID = selectedListID
            self.displayMode    = displayMode
            self.isPinned       = isPinned
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            lists          = (try? c.decode([TodoList].self,   forKey: .lists))          ?? []
            selectedListID = try? c.decode(UUID.self,          forKey: .selectedListID)
            displayMode    = (try? c.decode(DisplayMode.self,  forKey: .displayMode))    ?? .dropFromMenubar
            isPinned       = (try? c.decode(Bool.self,         forKey: .isPinned))       ?? false
        }
    }
}
