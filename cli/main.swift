// YATDL CLI — Yet Another To-Do List
// Author: Zac Leingang
//
// One-shot commands or full-screen TUI (-i / --tui).
// Reads and writes the same data file as the GUI app.
// Changes sync bidirectionally via the GUI's file watcher.

import Foundation
import Darwin

// ── ANSI ──────────────────────────────────────────────────────────────────────

private enum A {
    static let reset  = "\u{1B}[0m"
    static let bold   = "\u{1B}[1m"
    static let dim    = "\u{1B}[2m"
    static let rev    = "\u{1B}[7m"
    static let green  = "\u{1B}[32m"
    static let cyan   = "\u{1B}[36m"
    static let yellow = "\u{1B}[33m"
    static let red    = "\u{1B}[31m"
}

// ── Models ────────────────────────────────────────────────────────────────────

struct TodoItem: Identifiable, Codable, Equatable {
    var id        = UUID()
    var text:     String
    var icon:     String = ""
    var isDone:   Bool   = false
    var createdAt: Date  = Date()
}

struct TodoSection: Identifiable, Codable {
    var id    = UUID()
    var name: String
    var items: [TodoItem] = []

    private enum CodingKeys: String, CodingKey { case id, name, items }

    init(name: String, items: [TodoItem] = []) { self.name = name; self.items = items }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id    = (try? c.decode(UUID.self,       forKey: .id))    ?? UUID()
        name  = (try? c.decode(String.self,     forKey: .name))  ?? ""
        items = (try? c.decode([TodoItem].self, forKey: .items)) ?? []
    }
}

struct TodoList: Identifiable, Codable {
    var id       = UUID()
    var name:    String
    var icon:    String         = ""
    var color:   String         = ""
    var sections: [TodoSection] = []

    private enum CodingKeys: String, CodingKey { case id, name, icon, color, sections }
    private enum LegacyCodingKeys: String, CodingKey { case items }

    init(name: String) { self.name = name; self.sections = [TodoSection(name: "")] }

    init(from decoder: Decoder) throws {
        let c  = try  decoder.container(keyedBy: CodingKeys.self)
        let lc = try? decoder.container(keyedBy: LegacyCodingKeys.self)
        id    = (try? c.decode(UUID.self,   forKey: .id))    ?? UUID()
        name  = try  c.decode(String.self,  forKey: .name)
        icon  = (try? c.decode(String.self, forKey: .icon))  ?? ""
        color = (try? c.decode(String.self, forKey: .color)) ?? ""
        if let legacyItems = try? lc?.decode([TodoItem].self, forKey: .items) {
            sections = [TodoSection(name: "", items: legacyItems)]
        } else {
            let decoded = (try? c.decode([TodoSection].self, forKey: .sections)) ?? []
            sections = decoded.isEmpty ? [TodoSection(name: "")] : decoded
        }
    }

    // Convenience: all items across sections (for CLI display/numbering)
    var allItems: [TodoItem] { sections.flatMap { $0.items } }

    // Find the section and within-section index for a flat item number (1-based)
    func sectionAndIndex(for number: Int) -> (secIdx: Int, itemIdx: Int)? {
        var n = number - 1
        for (si, sec) in sections.enumerated() {
            if n < sec.items.count { return (si, n) }
            n -= sec.items.count
        }
        return nil
    }
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

// ── Store ─────────────────────────────────────────────────────────────────────

final class Store {
    let url: URL
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

    var allLists:   [TodoList] { data.lists }
    var current:    TodoList?  { data.lists.first { $0.id == data.selectedListID } }
    var selectedID: UUID?      { data.selectedListID }

    func reload() {
        guard let raw = try? Data(contentsOf: url),
              let p   = try? JSONDecoder().decode(Payload.self, from: raw) else { return }
        data = p
    }

    func fileModDate() -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    func save() {
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: url, options: .atomic)
        }
    }

    func currentTabIndex() -> Int {
        guard let id = data.selectedListID else { return 0 }
        return data.lists.firstIndex(where: { $0.id == id }) ?? 0
    }

    func switchTo(index: Int) {
        guard data.lists.indices.contains(index) else { return }
        data.selectedListID = data.lists[index].id
        save()
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
        if data.lists[idx].sections.isEmpty {
            data.lists[idx].sections = [TodoSection(name: "")]
        }
        data.lists[idx].sections[0].items.append(TodoItem(text: text))
        save()
    }

    func updateItem(at number: Int, text: String) {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        data.lists[lidx].sections[si].items[ii].text = trimmed
        save()
    }

    func toggleDone(at number: Int) {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number + 1) else { return }
        data.lists[lidx].sections[si].items[ii].isDone.toggle()
        save()
    }

    func setDone(_ number: Int, done: Bool) -> Bool {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number) else { return false }
        data.lists[lidx].sections[si].items[ii].isDone = done
        save()
        return true
    }

    func removeItemAt(_ number: Int) {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number + 1) else { return }
        data.lists[lidx].sections[si].items.remove(at: ii)
        save()
    }

    func removeItem(_ number: Int) -> Bool {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number) else { return false }
        data.lists[lidx].sections[si].items.remove(at: ii)
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
        if !data.lists.contains(where: { $0.id == data.selectedListID }) {
            data.selectedListID = data.lists[max(0, idx - 1)].id
        }
        save()
        return true
    }
}

// ── Terminal ──────────────────────────────────────────────────────────────────

private var savedTermios = termios()

private func enableRawMode() {
    tcgetattr(STDIN_FILENO, &savedTermios)
    var raw = savedTermios
    cfmakeraw(&raw)
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
}

private func restoreTermios() {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &savedTermios)
}

private func termSize() -> (w: Int, h: Int) {
    var ws = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0, ws.ws_col > 0 {
        return (Int(ws.ws_col), Int(ws.ws_row))
    }
    return (80, 24)
}

// ── Key input ─────────────────────────────────────────────────────────────────

private enum Key {
    case char(Character)
    case up, down, left, right, shiftTab
    case enter, tab, backspace, escape
}

private func readKey(timeoutMs: Int32 = 300) -> Key? {
    var pfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
    guard poll(&pfd, 1, timeoutMs) > 0 else { return nil }

    var buf = [UInt8](repeating: 0, count: 32)
    let n = read(STDIN_FILENO, &buf, 32)
    guard n > 0 else { return nil }

    let bytes = Array(buf.prefix(n))

    if bytes[0] == 0x1B {
        if n == 1 { return .escape }
        if n >= 3 && bytes[1] == 0x5B {
            switch bytes[2] {
            case 0x41: return .up
            case 0x42: return .down
            case 0x43: return .right
            case 0x44: return .left
            case 0x5A: return .shiftTab  // ESC [ Z
            default: break
            }
        }
        return nil
    }

    switch bytes[0] {
    case 0x0D, 0x0A: return .enter
    case 0x09:       return .tab
    case 0x7F, 0x08: return .backspace
    default:
        if let s = String(bytes: bytes, encoding: .utf8), let c = s.first {
            return .char(c)
        }
        return nil
    }
}

// ── TUI ───────────────────────────────────────────────────────────────────────

private struct TUI {
    let store:  Store
    var cursor: Int = 0
    var scroll: Int = 0

    enum Mode { case normal, addItem, editItem, addTab }
    var mode:      Mode   = .normal
    var inputBuf:  String = ""
    var editIndex: Int    = 0

    mutating func run() {
        enableRawMode()
        emit("\u{1B}[?1049h\u{1B}[?25l")  // alternate screen + hide cursor

        signal(SIGINT)  { _ in emit("\u{1B}[?1049l\u{1B}[?25h"); restoreTermios(); exit(0) }
        signal(SIGTERM) { _ in emit("\u{1B}[?1049l\u{1B}[?25h"); restoreTermios(); exit(0) }

        defer {
            emit("\u{1B}[?1049l\u{1B}[?25h")  // restore screen + cursor
            restoreTermios()
        }

        var lastMtime = store.fileModDate()

        while true {
            render()

            if let key = readKey() {
                if handleKey(key) { break }
            }

            let mtime = store.fileModDate()
            if mtime != lastMtime {
                store.reload()
                lastMtime = mtime
                clampCursor()
            }
        }
    }

    // MARK: – Rendering

    private func render() {
        let (w, h) = termSize()
        let items       = store.current?.allItems ?? []
        let visibleRows = max(0, h - 4)  // header + top divider + bottom divider + status

        var out = "\u{1B}[H"  // cursor home

        // Header: app name + tabs
        out += "\u{1B}[2K" + header() + "\r\n"

        // Top divider
        out += "\u{1B}[2K" + String(repeating: "─", count: w) + "\r\n"

        // Item rows
        var drawn = 0
        for i in scroll..<items.count {
            guard drawn < visibleRows else { break }
            out += "\u{1B}[2K" + itemLine(items[i], selected: i == cursor && mode == .normal) + "\r\n"
            drawn += 1
        }
        while drawn < visibleRows {
            out += "\u{1B}[2K\r\n"
            drawn += 1
        }

        // Bottom divider
        out += "\u{1B}[2K" + String(repeating: "─", count: w) + "\r\n"

        // Status / input bar
        out += "\u{1B}[2K" + statusLine()

        emit(out)
    }

    private func header() -> String {
        var s = " \(A.bold)YATDL\(A.reset)  "
        for list in store.allLists {
            let active = list.id == store.selectedID
            let icon   = list.icon.isEmpty ? "" : "\(list.icon) "
            if active {
                s += "\(A.cyan)\(A.bold)[\(icon)\(list.name)]\(A.reset)  "
            } else {
                s += "\(A.dim)\(icon)\(list.name)\(A.reset)  "
            }
        }
        return s
    }

    private func itemLine(_ item: TodoItem, selected: Bool) -> String {
        let cursor = selected ? "\(A.cyan)▶\(A.reset)" : " "
        let check  = item.isDone ? "\(A.green)✓\(A.reset)" : "\(A.dim)○\(A.reset)"
        let icon   = item.icon.isEmpty ? "" : "\(item.icon) "
        let text   = item.isDone
            ? "\(A.dim)\(icon)\(item.text)\(A.reset)"
            : "\(icon)\(item.text)"
        return " \(cursor) \(check)  \(text)"
    }

    private func statusLine() -> String {
        switch mode {
        case .normal:
            return "\(A.dim)j/k:move  Space:toggle  a:add  e:edit  d:del  Tab:next tab  n:new tab  q:quit\(A.reset)"
        case .addItem:
            return "\(A.cyan)Add item:\(A.reset) \(inputBuf)\(A.cyan)▌\(A.reset)"
        case .editItem:
            return "\(A.cyan)Edit:\(A.reset) \(inputBuf)\(A.cyan)▌\(A.reset)"
        case .addTab:
            return "\(A.cyan)New tab name:\(A.reset) \(inputBuf)\(A.cyan)▌\(A.reset)"
        }
    }

    // MARK: – Input handling

    mutating func handleKey(_ key: Key) -> Bool {
        switch mode {
        case .normal:    return handleNormal(key)
        case .addItem,
             .editItem,
             .addTab:    return handleTextInput(key)
        }
    }

    mutating func handleNormal(_ key: Key) -> Bool {
        let items = store.current?.allItems ?? []
        switch key {
        case .char("q"), .escape:
            return true
        case .char("j"), .down:
            if cursor < items.count - 1 { cursor += 1; adjustScroll() }
        case .char("k"), .up:
            if cursor > 0 { cursor -= 1; adjustScroll() }
        case .char(" "):
            if items.indices.contains(cursor) { store.toggleDone(at: cursor) }
        case .char("a"):
            mode = .addItem;  inputBuf = ""
        case .char("e"):
            if items.indices.contains(cursor) {
                editIndex = cursor; inputBuf = items[cursor].text; mode = .editItem
            }
        case .char("d"), .backspace:
            if items.indices.contains(cursor) { store.removeItemAt(cursor); clampCursor() }
        case .tab, .right:
            nextTab()
        case .shiftTab, .left:
            prevTab()
        case .char("n"):
            mode = .addTab; inputBuf = ""
        default: break
        }
        return false
    }

    mutating func handleTextInput(_ key: Key) -> Bool {
        switch key {
        case .escape:
            mode = .normal; inputBuf = ""
        case .enter:
            commitInput()
        case .backspace:
            if !inputBuf.isEmpty { inputBuf.removeLast() }
        case .char(let c):
            inputBuf.append(c)
        default: break
        }
        return false
    }

    mutating func commitInput() {
        let text = inputBuf.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .addItem:
            if !text.isEmpty {
                store.addItem(text)
                cursor = max(0, (store.current?.allItems.count ?? 1) - 1)
                adjustScroll()
            }
        case .editItem:
            if !text.isEmpty { store.updateItem(at: editIndex, text: text) }
        case .addTab:
            if !text.isEmpty { store.newTab(text); cursor = 0; scroll = 0 }
        case .normal: break
        }
        mode = .normal; inputBuf = ""
    }

    mutating func nextTab() {
        let n = store.allLists.count
        store.switchTo(index: (store.currentTabIndex() + 1) % n)
        cursor = 0; scroll = 0
    }

    mutating func prevTab() {
        let n = store.allLists.count
        store.switchTo(index: (store.currentTabIndex() + n - 1) % n)
        cursor = 0; scroll = 0
    }

    mutating func clampCursor() {
        let count = store.current?.allItems.count ?? 0
        if count == 0 { cursor = 0; scroll = 0; return }
        cursor = min(cursor, count - 1)
        adjustScroll()
    }

    mutating func adjustScroll() {
        let (_, h) = termSize()
        let visible = max(1, h - 4)
        if cursor < scroll             { scroll = cursor }
        if cursor >= scroll + visible  { scroll = cursor - visible + 1 }
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private func emit(_ s: String) {
    Swift.print(s, terminator: "")
    fflush(stdout)
}

// ── One-shot rendering ────────────────────────────────────────────────────────

private func printCurrent(_ store: Store) {
    guard let list = store.current else { print("No list selected."); return }
    let icon = list.icon.isEmpty ? "" : "\(list.icon) "
    print("\(A.bold)\(A.cyan)[\(icon)\(list.name)]\(A.reset)")
    if list.allItems.isEmpty { print("  \(A.dim)(empty)\(A.reset)"); return }
    for (i, item) in list.allItems.enumerated() {
        let num   = String(format: "%2d", i + 1)
        let mark  = item.isDone ? "\(A.green)✓\(A.reset)" : " "
        let iIcon = item.icon.isEmpty ? "" : "\(item.icon) "
        let text  = item.isDone ? "\(A.dim)\(iIcon)\(item.text)\(A.reset)" : "\(iIcon)\(item.text)"
        print("  \(A.dim)\(num).\(A.reset) \(mark)  \(text)")
    }
}

private func printAll(_ store: Store) {
    let sel = store.current?.id
    for list in store.allLists {
        let arrow = list.id == sel ? "\(A.cyan)→\(A.reset)" : " "
        let icon  = list.icon.isEmpty ? "" : "\(list.icon) "
        let count = list.allItems.count
        let badge = "\(A.dim)(\(count) item\(count == 1 ? "" : "s"))\(A.reset)"
        print("  \(arrow) \(A.bold)\(icon)\(list.name)\(A.reset)  \(badge)")
    }
}

private func printHelp() {
    print("""
\(A.bold)yatdl-cli\(A.reset) — Yet Another To-Do List

  yatdl-cli                show current list
  yatdl-cli lists          show all lists
  yatdl-cli use <name>     switch to list
  yatdl-cli add <text>     add item to current list
  yatdl-cli done <num>     mark item done
  yatdl-cli undo <num>     mark item not done
  yatdl-cli rm <num>       remove item
  yatdl-cli newtab <name>  create new list
  yatdl-cli rmtab <name>   delete list
  yatdl-cli -i             launch full-screen TUI
  yatdl-cli help           show this help
""")
}

// ── Entry point ───────────────────────────────────────────────────────────────

let store = Store()
let argv  = CommandLine.arguments.dropFirst()

switch argv.first {
case nil:
    printCurrent(store)
case "-i", "--tui":
    var tui = TUI(store: store)
    tui.run()
case "lists":
    printAll(store)
case "use":
    if let name = argv.dropFirst().first {
        if store.switchTo(name: name) { print("→ \(name)") }
        else { fputs("not found\n", stderr); exit(1) }
    }
case "add":
    let text = argv.dropFirst().joined(separator: " ")
    guard !text.isEmpty else { fputs("usage: yatdl-cli add <text>\n", stderr); exit(1) }
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
