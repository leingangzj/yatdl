// YATDL CLI — Yet Another To-Do List
// Author: Zac Leingang
//
// Reads and writes the same data file as the GUI app.
// Any changes here are picked up by the GUI's file watcher in real time.

import Foundation

// ── ANSI helpers ──────────────────────────────────────────────────────────

private enum C {
    static let reset  = "\u{1B}[0m"
    static let bold   = "\u{1B}[1m"
    static let dim    = "\u{1B}[2m"
    static let green  = "\u{1B}[32m"
    static let cyan   = "\u{1B}[36m"
    static let red    = "\u{1B}[31m"
}

// ── Models (mirror of GUI models — same Codable layout) ───────────────────

struct TodoItem: Identifiable, Codable, Equatable {
    var id        = UUID()
    var text:     String
    var isDone:   Bool = false
    var createdAt: Date = Date()
}

struct TodoList: Identifiable, Codable {
    var id    = UUID()
    var name:  String
    var items: [TodoItem] = []
}

enum DisplayMode: String, Codable {
    case dropFromMenubar
    case slideFromRight
}

struct Payload: Codable {
    var lists:          [TodoList]
    var selectedListID: UUID?
    var displayMode:    DisplayMode
}

// ── Store ─────────────────────────────────────────────────────────────────

final class Store {
    private let url: URL
    private var data: Payload

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("YATDL")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("data.json")

        if let raw = try? Data(contentsOf: url),
           let p   = try? JSONDecoder().decode(Payload.self, from: raw) {
            data = p
        } else {
            let list = TodoList(name: "Personal")
            data = Payload(lists: [list], selectedListID: list.id, displayMode: .dropFromMenubar)
        }
    }

    var allLists: [TodoList]  { data.lists }
    var current:  TodoList?   { data.lists.first { $0.id == data.selectedListID } }

    func save() {
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: url, options: .atomic)
        }
    }

    func switchTo(name: String) -> Bool {
        guard let list = data.lists.first(where: { $0.name.lowercased() == name.lowercased() }) else { return false }
        data.selectedListID = list.id
        save()
        return true
    }

    func addItem(_ text: String) {
        guard let id  = data.selectedListID,
              let idx = data.lists.firstIndex(where: { $0.id == id }) else { return }
        data.lists[idx].items.append(TodoItem(text: text))
        save()
    }

    func setDone(_ number: Int, done: Bool) -> Bool {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }) else { return false }
        let iidx = number - 1
        guard data.lists[lidx].items.indices.contains(iidx) else { return false }
        data.lists[lidx].items[iidx].isDone = done
        save()
        return true
    }

    func removeItem(_ number: Int) -> Bool {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }) else { return false }
        let iidx = number - 1
        guard data.lists[lidx].items.indices.contains(iidx) else { return false }
        data.lists[lidx].items.remove(at: iidx)
        save()
        return true
    }

    func newTab(_ name: String) {
        let list = TodoList(name: name)
        data.lists.append(list)
        data.selectedListID = list.id
        save()
    }

    func removeTab(_ name: String) -> Bool {
        guard data.lists.count > 1,
              let idx = data.lists.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) else { return false }
        data.lists.remove(at: idx)
        // If the removed tab was selected, fall back to the previous one
        if !data.lists.contains(where: { $0.id == data.selectedListID }) {
            data.selectedListID = data.lists[max(0, idx - 1)].id
        }
        save()
        return true
    }
}

// ── Rendering ─────────────────────────────────────────────────────────────

private func printCurrent(_ store: Store) {
    guard let list = store.current else { print("No list selected."); return }
    print("\(C.bold)\(C.cyan)[\(list.name)]\(C.reset)")
    if list.items.isEmpty { print("  \(C.dim)(empty)\(C.reset)"); return }
    for (i, item) in list.items.enumerated() {
        let num  = String(format: "%2d", i + 1)
        let mark = item.isDone ? "\(C.green)✓\(C.reset)" : " "
        let text = item.isDone ? "\(C.dim)\(item.text)\(C.reset)" : item.text
        print("  \(C.dim)\(num).\(C.reset) \(mark)  \(text)")
    }
}

private func printAll(_ store: Store) {
    let sel = store.current?.id
    for list in store.allLists {
        let arrow = list.id == sel ? "\(C.cyan)→\(C.reset)" : " "
        let count = "\(C.dim)(\(list.items.count) item\(list.items.count == 1 ? "" : "s"))\(C.reset)"
        print("  \(arrow) \(C.bold)\(list.name)\(C.reset)  \(count)")
    }
}

private func printHelp() {
    print("""
\(C.bold)yatdl\(C.reset) — Yet Another To-Do List

  yatdl                 show current list
  yatdl lists           show all lists
  yatdl use <name>      switch to list
  yatdl add <text>      add item to current list
  yatdl done <num>      mark item done
  yatdl undo <num>      mark item not done
  yatdl rm <num>        remove item
  yatdl newtab <name>   create new list
  yatdl rmtab <name>    delete list
  yatdl -i              interactive mode
  yatdl help            show this help
""")
}

// ── Interactive REPL ──────────────────────────────────────────────────────

private func runInteractive(_ store: Store) {
    print("\(C.bold)YATDL\(C.reset)  type \(C.dim)help\(C.reset) or \(C.dim)exit\(C.reset)")
    printCurrent(store)

    while true {
        let tab = store.current?.name ?? "?"
        print("\(C.cyan)[\(tab)]\(C.reset) > ", terminator: "")

        guard let line = readLine(strippingNewline: true) else { break }
        let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
        guard let cmd = parts.first, !cmd.isEmpty else { continue }

        switch cmd {
        case "exit", "quit", "q":
            return
        case "help":
            printHelp()
        case "ls", "list":
            printCurrent(store)
        case "lists":
            printAll(store)
        case "use":
            if let name = parts.last {
                if store.switchTo(name: name) { print("→ \(name)"); printCurrent(store) }
                else { print("\(C.red)not found\(C.reset)") }
            }
        case "add":
            if let text = parts.last { store.addItem(text); print("+ \(text)") }
        case "done":
            if let n = parts.last.flatMap(Int.init), store.setDone(n, done: true) { print("✓") }
            else { print("\(C.red)invalid number\(C.reset)") }
        case "undo":
            if let n = parts.last.flatMap(Int.init), store.setDone(n, done: false) { print("○") }
            else { print("\(C.red)invalid number\(C.reset)") }
        case "rm":
            if let n = parts.last.flatMap(Int.init), store.removeItem(n) { print("removed") }
            else { print("\(C.red)invalid number\(C.reset)") }
        case "newtab":
            if let name = parts.last { store.newTab(name); print("created \(name)") }
        case "rmtab":
            if let name = parts.last {
                if store.removeTab(name) { print("removed \(name)") }
                else { print("\(C.red)cannot remove (not found or last list)\(C.reset)") }
            }
        default:
            print("\(C.dim)unknown: \(cmd)\(C.reset)")
        }
    }
}

// ── Entry point ───────────────────────────────────────────────────────────

let store = Store()
let argv  = CommandLine.arguments.dropFirst()

switch argv.first {
case nil:
    printCurrent(store)
case "-i":
    runInteractive(store)
case "lists":
    printAll(store)
case "use":
    if let name = argv.dropFirst().first {
        if store.switchTo(name: name) { print("→ \(name)") }
        else { fputs("not found\n", stderr); exit(1) }
    }
case "add":
    let text = argv.dropFirst().joined(separator: " ")
    guard !text.isEmpty else { fputs("usage: yatdl add <text>\n", stderr); exit(1) }
    store.addItem(text)
    print("+ \(text)")
case "done":
    if let n = argv.dropFirst().first.flatMap(Int.init), store.setDone(n, done: true) { print("✓") }
    else { fputs("invalid number\n", stderr); exit(1) }
case "undo":
    if let n = argv.dropFirst().first.flatMap(Int.init), store.setDone(n, done: false) { print("○") }
    else { fputs("invalid number\n", stderr); exit(1) }
case "rm":
    if let n = argv.dropFirst().first.flatMap(Int.init), store.removeItem(n) { print("removed") }
    else { fputs("invalid number\n", stderr); exit(1) }
case "newtab":
    if let name = argv.dropFirst().first { store.newTab(name); print("created \(name)") }
case "rmtab":
    if let name = argv.dropFirst().first {
        if store.removeTab(name) { print("removed \(name)") }
        else { fputs("cannot remove (not found or last list)\n", stderr); exit(1) }
    }
case "help", "--help", "-h":
    printHelp()
default:
    printHelp()
    exit(1)
}
