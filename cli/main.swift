// YATDL CLI — Yet Another To-Do List
// Author: Zac Leingang
//
// One-shot commands or a full-screen TUI (yatdl -i).
// Reads and writes the same data file as the GUI app — changes sync
// bidirectionally through the GUI's kqueue file watcher.

import Foundation
import Darwin

// ── ANSI helpers ──────────────────────────────────────────────────────────────

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

private func emit(_ s: String) {
    Swift.print(s, terminator: "")
    fflush(stdout)
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
    var id        = UUID()
    var name:     String
    var icon:     String         = ""
    var sections: [TodoSection] = []

    // Legacy key retained only for reading old flat-items JSON.
    private enum CodingKeys:       String, CodingKey { case id, name, icon, sections }
    private enum LegacyCodingKeys: String, CodingKey { case items, color }

    init(name: String) { self.name = name; self.sections = [TodoSection(name: "")] }

    init(from decoder: Decoder) throws {
        let c  = try  decoder.container(keyedBy: CodingKeys.self)
        let lc = try? decoder.container(keyedBy: LegacyCodingKeys.self)
        id   = (try? c.decode(UUID.self,   forKey: .id))   ?? UUID()
        name = try  c.decode(String.self,  forKey: .name)
        icon = (try? c.decode(String.self, forKey: .icon)) ?? ""
        if let legacyItems = try? lc?.decode([TodoItem].self, forKey: .items) {
            sections = [TodoSection(name: "", items: legacyItems)]
        } else {
            let decoded = (try? c.decode([TodoSection].self, forKey: .sections)) ?? []
            sections = decoded.isEmpty ? [TodoSection(name: "")] : decoded
        }
    }

    var allItems: [TodoItem] { sections.flatMap { $0.items } }

    // Maps a 1-based flat item number to its section and within-section index.
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

    // Appends to the last section (matches desktop app behaviour).
    func addItem(_ text: String) {
        guard let id  = data.selectedListID,
              let idx = data.lists.firstIndex(where: { $0.id == id }) else { return }
        if data.lists[idx].sections.isEmpty {
            data.lists[idx].sections = [TodoSection(name: "")]
        }
        let last = data.lists[idx].sections.count - 1
        data.lists[idx].sections[last].items.append(TodoItem(text: text))
        save()
    }

    // number is 1-based (matches CLI display numbering).
    func setDone(_ number: Int, done: Bool) -> Bool {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number) else { return false }
        data.lists[lidx].sections[si].items[ii].isDone = done
        save()
        return true
    }

    // number is 1-based.
    func removeItem(_ number: Int) -> Bool {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number) else { return false }
        data.lists[lidx].sections[si].items.remove(at: ii)
        save()
        return true
    }

    // number is 1-based.
    func updateItem(number: Int, text: String) -> Bool {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number) else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        data.lists[lidx].sections[si].items[ii].text = trimmed
        save()
        return true
    }

    func toggleItem(number: Int) {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number) else { return }
        data.lists[lidx].sections[si].items[ii].isDone.toggle()
        save()
    }

    func addSection(_ name: String) {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }) else { return }
        data.lists[lidx].sections.append(TodoSection(name: name))
        save()
    }

    func renameSection(sectionIdx: Int, name: String) {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              data.lists[lidx].sections.indices.contains(sectionIdx) else { return }
        data.lists[lidx].sections[sectionIdx].name = name
        save()
    }

    // Orphaned items fold into the first remaining section (matches desktop behaviour).
    func deleteSection(sectionIdx: Int) {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              data.lists[lidx].sections.indices.contains(sectionIdx) else { return }
        let orphans = data.lists[lidx].sections[sectionIdx].items
        data.lists[lidx].sections.remove(at: sectionIdx)
        if data.lists[lidx].sections.isEmpty {
            data.lists[lidx].sections = [TodoSection(name: "")]
        }
        if !orphans.isEmpty {
            data.lists[lidx].sections[0].items.insert(contentsOf: orphans, at: 0)
        }
        save()
    }

    // number is 1-based. Pass "" to clear the icon.
    @discardableResult
    func setItemIcon(number: Int, icon: String) -> Bool {
        guard let id   = data.selectedListID,
              let lidx = data.lists.firstIndex(where: { $0.id == id }),
              let (si, ii) = data.lists[lidx].sectionAndIndex(for: number) else { return false }
        data.lists[lidx].sections[si].items[ii].icon = icon
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

// ── Terminal raw mode ─────────────────────────────────────────────────────────

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
    case delete   // forward-delete (Fn+Delete on Mac)
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
            case 0x5A: return .shiftTab         // ESC [ Z
            case 0x33: return n >= 4 && bytes[3] == 0x7E ? .delete : nil  // ESC [ 3 ~
            default:   break
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

// ── TUI row model ─────────────────────────────────────────────────────────────

// A flat list of rows mixing section headers and items for unified navigation.
private enum TUIRow {
    case sectionHeader(sectionIdx: Int, name: String)
    case item(sectionIdx: Int, itemIdx: Int, flatNum: Int, item: TodoItem)

    var isItem: Bool {
        if case .item = self { return true }
        return false
    }
}

private func buildRows(for list: TodoList) -> [TUIRow] {
    var rows: [TUIRow] = []
    var flatNum = 1
    for (si, section) in list.sections.enumerated() {
        if !section.name.isEmpty {
            rows.append(.sectionHeader(sectionIdx: si, name: section.name))
        }
        for (ii, item) in section.items.enumerated() {
            rows.append(.item(sectionIdx: si, itemIdx: ii, flatNum: flatNum, item: item))
            flatNum += 1
        }
    }
    return rows
}


// ── TUI ───────────────────────────────────────────────────────────────────────

private struct TUI {
    let store: Store
    var cursor: Int = 0   // index into current rows array
    var scroll: Int = 0   // first visible row index

    enum Mode { case normal, addItem, editItem, addTab, addSection, renameSection, setIcon }
    var mode:          Mode   = .normal
    var inputBuf:      String = ""
    var editFlatNum:   Int    = 0   // 1-based item number being edited
    var editSecIdx:    Int    = 0   // section index being renamed/deleted

    mutating func run() {
        enableRawMode()
        emit("\u{1B}[?1049h\u{1B}[?25l")   // alternate screen, hide cursor

        signal(SIGINT)  { _ in emit("\u{1B}[?1049l\u{1B}[?25h"); restoreTermios(); exit(0) }
        signal(SIGTERM) { _ in emit("\u{1B}[?1049l\u{1B}[?25h"); restoreTermios(); exit(0) }

        defer {
            emit("\u{1B}[?1049l\u{1B}[?25h")  // restore screen, show cursor
            restoreTermios()
        }

        var lastMtime = store.fileModDate()
        clampCursor(rows: buildRows(for: store.current ?? TodoList(name: "")))

        while true {
            let rows = buildRows(for: store.current ?? TodoList(name: ""))
            render(rows: rows)

            if let key = readKey() {
                if handleKey(key, rows: rows) { break }
            }

            // Reload when the GUI (or another CLI instance) writes the file.
            let mtime = store.fileModDate()
            if mtime != lastMtime {
                store.reload()
                lastMtime = mtime
                clampCursor(rows: buildRows(for: store.current ?? TodoList(name: "")))
            }
        }
    }

    // MARK: – Rendering

    private func render(rows: [TUIRow]) {
        let (w, h) = termSize()
        let bodyRows = max(0, h - 4)   // 1 header + 1 divider top + 1 divider bottom + 1 status

        var out = "\u{1B}[H"   // cursor home

        out += "\u{1B}[2K" + renderHeader(width: w) + "\r\n"
        out += "\u{1B}[2K" + String(repeating: "─", count: w) + "\r\n"

        var drawn = 0
        for i in scroll..<rows.count {
            guard drawn < bodyRows else { break }
            out += "\u{1B}[2K" + renderRow(rows[i], selected: i == cursor && mode == .normal, width: w) + "\r\n"
            drawn += 1
        }
        while drawn < bodyRows { out += "\u{1B}[2K\r\n"; drawn += 1 }

        out += "\u{1B}[2K" + String(repeating: "─", count: w) + "\r\n"
        out += "\u{1B}[2K" + renderStatus(currentRow: rows[safe: cursor])

        emit(out)
    }

    private func renderHeader(width: Int) -> String {
        var s = " \(A.bold)YATDL\(A.reset)  "
        for list in store.allLists {
            let sel  = list.id == store.selectedID
            let icon = list.icon.isEmpty ? "" : "\(list.icon) "
            s += sel
                ? "\(A.cyan)\(A.bold)[\(icon)\(list.name)]\(A.reset)  "
                : "\(A.dim)\(icon)\(list.name)\(A.reset)  "
        }
        return s
    }

    private func renderRow(_ row: TUIRow, selected: Bool, width: Int) -> String {
        switch row {
        case .sectionHeader(_, let name):
            let prefix = selected ? "\(A.cyan)▶\(A.reset)" : " "
            return " \(prefix) \(A.dim)\(A.bold)── \(name.uppercased())\(A.reset)"

        case .item(_, _, _, let item):
            let arrow = selected ? "\(A.cyan)▶\(A.reset)" : " "
            let check = item.isDone ? "\(A.green)✓\(A.reset)" : "\(A.dim)○\(A.reset)"
            let icon  = item.icon.isEmpty ? "" : "\(item.icon) "
            let text  = item.isDone
                ? "\(A.dim)\(icon)\(item.text)\(A.reset)"
                : "\(icon)\(item.text)"
            return " \(arrow) \(check)  \(text)"
        }
    }

    private func renderStatus(currentRow: TUIRow?) -> String {
        switch mode {
        case .normal:
            switch currentRow {
            case .sectionHeader:
                return "\(A.dim)↑↓ move  r rename section  d delete section  s new section  tab next list  q quit\(A.reset)"
            default:
                return "\(A.dim)↑↓ move  spc toggle  a add  e edit  i icon  d del  s section  tab next  q quit\(A.reset)"
            }
        case .addItem:
            return "\(A.cyan)+ New item:\(A.reset) \(inputBuf)\(A.cyan)▌\(A.reset)"
        case .editItem:
            return "\(A.cyan)✎ Edit:\(A.reset) \(inputBuf)\(A.cyan)▌\(A.reset)"
        case .addTab:
            return "\(A.cyan)+ New list name:\(A.reset) \(inputBuf)\(A.cyan)▌\(A.reset)"
        case .addSection:
            return "\(A.cyan)+ New section name:\(A.reset) \(inputBuf)\(A.cyan)▌\(A.reset)"
        case .renameSection:
            return "\(A.cyan)✎ Rename section:\(A.reset) \(inputBuf)\(A.cyan)▌\(A.reset)"
        case .setIcon:
            return "\(A.cyan)✎ Item icon (emoji or blank to clear):\(A.reset) \(inputBuf)\(A.cyan)▌\(A.reset)"
        }
    }

    // MARK: – Input dispatch

    mutating func handleKey(_ key: Key, rows: [TUIRow]) -> Bool {
        switch mode {
        case .normal: return handleNormal(key, rows: rows)
        default:      return handleTextInput(key)
        }
    }

    mutating func handleNormal(_ key: Key, rows: [TUIRow]) -> Bool {
        switch key {
        case .char("q"), .escape:
            return true

        case .char("j"), .down:
            if cursor < rows.count - 1 { cursor += 1; adjustScroll(rows: rows) }

        case .char("k"), .up:
            if cursor > 0 { cursor -= 1; adjustScroll(rows: rows) }

        case .char(" "):
            if case .item(_, _, let num, _) = rows[safe: cursor] {
                store.toggleItem(number: num)
            }

        case .char("a"):
            mode = .addItem; inputBuf = ""

        case .char("e"):
            if case .item(_, _, let num, let item) = rows[safe: cursor] {
                editFlatNum = num; inputBuf = item.text; mode = .editItem
            }

        case .char("i"):
            if case .item(_, _, let num, let item) = rows[safe: cursor] {
                editFlatNum = num; inputBuf = item.icon; mode = .setIcon
            }

        case .char("s"):
            mode = .addSection; inputBuf = ""

        case .char("r"):
            if case .sectionHeader(let si, let name) = rows[safe: cursor] {
                editSecIdx = si; inputBuf = name; mode = .renameSection
            }

        case .char("d"), .delete:
            switch rows[safe: cursor] {
            case .item(_, _, let num, _):
                _ = store.removeItem(num)
                clampCursor(rows: buildRows(for: store.current ?? TodoList(name: "")))
            case .sectionHeader(let si, _):
                store.deleteSection(sectionIdx: si)
                clampCursor(rows: buildRows(for: store.current ?? TodoList(name: "")))
            default: break
            }

        case .tab, .right, .char("l"):
            nextTab()

        case .shiftTab, .left, .char("h"):
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
                let newRows = buildRows(for: store.current ?? TodoList(name: ""))
                cursor = newRows.indices.last(where: { newRows[$0].isItem }) ?? 0
                adjustScroll(rows: newRows)
            }
        case .editItem:
            if !text.isEmpty { _ = store.updateItem(number: editFlatNum, text: text) }
        case .addTab:
            if !text.isEmpty { store.newTab(text); cursor = 0; scroll = 0 }
        case .addSection:
            if !text.isEmpty {
                store.addSection(text)
                let newRows = buildRows(for: store.current ?? TodoList(name: ""))
                // Land on the new section header.
                cursor = newRows.indices.last ?? 0
                adjustScroll(rows: newRows)
            }
        case .renameSection:
            if !text.isEmpty { store.renameSection(sectionIdx: editSecIdx, name: text) }
        case .setIcon:
            // Allow empty string to clear the icon.
            store.setItemIcon(number: editFlatNum, icon: text)
        case .normal: break
        }
        mode = .normal; inputBuf = ""
    }

    // MARK: – Tab switching

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

    // MARK: – Scroll management

    mutating func clampCursor(rows: [TUIRow]) {
        if rows.isEmpty { cursor = 0; scroll = 0; return }
        if !rows.indices.contains(cursor) { cursor = max(0, rows.count - 1) }
        adjustScroll(rows: rows)
    }

    mutating func adjustScroll(rows: [TUIRow]) {
        let (_, h) = termSize()
        let visible = max(1, h - 4)
        if cursor < scroll             { scroll = cursor }
        if cursor >= scroll + visible  { scroll = cursor - visible + 1 }
    }
}

// Safe subscript for arrays.
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// ── One-shot output ───────────────────────────────────────────────────────────

private func printCurrent(_ store: Store) {
    guard let list = store.current else { print("No list selected."); return }
    let icon = list.icon.isEmpty ? "" : "\(list.icon) "
    print("\(A.bold)\(A.cyan)[\(icon)\(list.name)]\(A.reset)")
    var flatNum = 1
    for section in list.sections {
        if !section.name.isEmpty {
            print("  \(A.dim)\(A.bold)── \(section.name.uppercased())\(A.reset)")
        }
        for item in section.items {
            let num  = String(format: "%2d", flatNum)
            let mark = item.isDone ? "\(A.green)✓\(A.reset)" : " "
            let ic   = item.icon.isEmpty ? "" : "\(item.icon) "
            let text = item.isDone ? "\(A.dim)\(ic)\(item.text)\(A.reset)" : "\(ic)\(item.text)"
            print("  \(A.dim)\(num).\(A.reset) \(mark)  \(text)")
            flatNum += 1
        }
    }
    if list.allItems.isEmpty { print("  \(A.dim)(empty)\(A.reset)") }
}

private func printAll(_ store: Store) {
    for list in store.allLists {
        let arrow = list.id == store.selectedID ? "\(A.cyan)→\(A.reset)" : " "
        let icon  = list.icon.isEmpty ? "" : "\(list.icon) "
        let count = list.allItems.count
        let badge = "\(A.dim)(\(count) item\(count == 1 ? "" : "s"))\(A.reset)"
        print("  \(arrow) \(A.bold)\(icon)\(list.name)\(A.reset)  \(badge)")
    }
}

private func printHelp() {
    print("""
\(A.bold)yatdl\(A.reset) — Yet Another To-Do List CLI

  \(A.bold)One-shot commands\(A.reset)
  yatdl                show current list
  yatdl lists          show all lists
  yatdl use <name>     switch to list
  yatdl add <text>     add item to current list
  yatdl done <num>     mark item done
  yatdl undo <num>     mark item not done
  yatdl rm <num>       remove item
  yatdl newtab <name>  create new list
  yatdl rmtab <name>   delete list
  yatdl help           show this help

  \(A.bold)Interactive TUI\(A.reset)
  yatdl -i             launch full-screen TUI

  \(A.bold)TUI keys — items\(A.reset)
  ↑ ↓ / j k   navigate
  Space        toggle done
  a            add item
  e            edit item
  i            set icon (emoji, blank to clear)
  d            delete item
  s            add section
  Tab / →      next list
  Shift+Tab / ←  previous list
  n            new list
  q / Esc      quit

  \(A.bold)TUI keys — section headers\(A.reset)
  r            rename section
  d            delete section
""")
}

// ── Entry point ───────────────────────────────────────────────────────────────

let store = Store()
let args  = CommandLine.arguments.dropFirst()

switch args.first {
case nil:
    printCurrent(store)
case "-i", "--tui":
    var tui = TUI(store: store)
    tui.run()
case "lists":
    printAll(store)
case "use":
    if let name = args.dropFirst().first {
        if store.switchTo(name: name) { print("→ \(name)") }
        else { fputs("list not found: \(name)\n", stderr); exit(1) }
    }
case "add":
    let text = args.dropFirst().joined(separator: " ")
    guard !text.isEmpty else { fputs("usage: yatdl add <text>\n", stderr); exit(1) }
    store.addItem(text)
    print("+ \(text)")
case "done":
    if let n = args.dropFirst().first.flatMap(Int.init), store.setDone(n, done: true) { print("✓") }
    else { fputs("invalid item number\n", stderr); exit(1) }
case "undo":
    if let n = args.dropFirst().first.flatMap(Int.init), store.setDone(n, done: false) { print("○") }
    else { fputs("invalid item number\n", stderr); exit(1) }
case "rm":
    if let n = args.dropFirst().first.flatMap(Int.init), store.removeItem(n) { print("removed") }
    else { fputs("invalid item number\n", stderr); exit(1) }
case "newtab":
    if let name = args.dropFirst().first { store.newTab(name); print("created \(name)") }
    else { fputs("usage: yatdl newtab <name>\n", stderr); exit(1) }
case "rmtab":
    if let name = args.dropFirst().first {
        if store.removeTab(name) { print("removed \(name)") }
        else { fputs("cannot remove: not found or last list\n", stderr); exit(1) }
    } else { fputs("usage: yatdl rmtab <name>\n", stderr); exit(1) }
case "help", "--help", "-h":
    printHelp()
default:
    fputs("unknown command. Run `yatdl help` for usage.\n", stderr)
    exit(1)
}
