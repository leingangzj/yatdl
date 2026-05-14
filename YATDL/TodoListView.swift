// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI
import AppKit

// MARK: – List view

struct TodoListView: View {
    @EnvironmentObject var store:    TodoStore
    @EnvironmentObject var settings: AppSettings
    @Binding var list: TodoList

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($list.sections) { $section in
                        SectionBlock(
                            section: $section,
                            list: $list,
                            store: store,
                            settings: settings,
                            onMoveItem: moveItem,
                            onMoveItemToSection: moveItemToSection,
                            onReorderSection: reorderSection
                        )
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal:   .opacity
                        ))
                    }
                }
                .padding(.vertical, 4)
                .animation(.spring(response: 0.22, dampingFraction: 0.85), value: list.sections.count)
            }

            Divider()

            // ── Bottom action bar ─────────────────────────────────────────
            HStack(spacing: 0) {
                actionButton("plus.circle",       "Add item")    { addItem()    }
                Divider().frame(height: 14)
                actionButton("folder.badge.plus", "Add tab") { addTab() }
                    .disabled(store.lists.count >= maxListCount)
                    .opacity(store.lists.count >= maxListCount ? 0.35 : 1)
                Divider().frame(height: 14)
                actionButton("rectangle.3.group", "Add section") { addSection() }
            }
            .padding(.vertical, 8)
        }
    }

    private func actionButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: – Actions

    private func addItem() {
        if list.sections.isEmpty { list.sections = [TodoSection(name: "")] }
        let item = TodoItem(text: "")
        let lastIdx = list.sections.count - 1
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            list.sections[lastIdx].items.append(item)
        }
        store.pendingEditItemID = item.id
        store.save()
    }

    private func addTab() {
        guard store.lists.count < maxListCount else { return }
        let newList = TodoList(name: "New Tab")
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            store.lists.append(newList)
            store.selectedListID = newList.id
        }
        store.pendingRenameListID = newList.id
        store.save()
    }

    private func addSection() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            list.sections.append(TodoSection(name: "New Section"))
        }
        store.save()
    }

    // MARK: – Drag-drop helpers

    func moveItemToSection(payloads: [String], targetSectionID: UUID) -> Bool {
        guard let payload = payloads.first else { return false }
        let parts = payload.components(separatedBy: ":")
        guard parts.count == 2,
              let fromSectionID = UUID(uuidString: parts[0]),
              let itemID        = UUID(uuidString: parts[1]),
              fromSectionID != targetSectionID,
              let fromSI = list.sections.firstIndex(where: { $0.id == fromSectionID }),
              let ii     = list.sections[fromSI].items.firstIndex(where: { $0.id == itemID }),
              let toSI   = list.sections.firstIndex(where: { $0.id == targetSectionID })
        else { return false }
        let moved = list.sections[fromSI].items.remove(at: ii)
        list.sections[toSI].items.append(moved)
        store.save()
        return true
    }

    func moveItem(payloads: [String], toSectionID: UUID, beforeItemID: UUID) -> Bool {
        guard let payload = payloads.first else { return false }
        let parts = payload.components(separatedBy: ":")
        guard parts.count == 2,
              let fromSectionID = UUID(uuidString: parts[0]),
              let itemID        = UUID(uuidString: parts[1]),
              let toSI   = list.sections.firstIndex(where: { $0.id == toSectionID }),
              let toII   = list.sections[toSI].items.firstIndex(where: { $0.id == beforeItemID })
        else { return false }

        if fromSectionID == toSectionID {
            guard let fromII = list.sections[toSI].items.firstIndex(where: { $0.id == itemID }),
                  fromII != toII else { return false }
            list.sections[toSI].items.move(
                fromOffsets: IndexSet([fromII]),
                toOffset: toII > fromII ? toII + 1 : toII
            )
        } else {
            guard let fromSI = list.sections.firstIndex(where: { $0.id == fromSectionID }),
                  let fromII = list.sections[fromSI].items.firstIndex(where: { $0.id == itemID })
            else { return false }
            let moved = list.sections[fromSI].items.remove(at: fromII)
            list.sections[toSI].items.insert(moved, at: toII)
        }
        store.save()
        return true
    }

    func reorderSection(payload: String, toSectionID: UUID) -> Bool {
        let idStr = String(payload.dropFirst("section:".count))
        guard let fromID = UUID(uuidString: idStr),
              fromID != toSectionID,
              let fromIdx = list.sections.firstIndex(where: { $0.id == fromID }),
              let toIdx   = list.sections.firstIndex(where: { $0.id == toSectionID })
        else { return false }
        list.sections.move(
            fromOffsets: IndexSet([fromIdx]),
            toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx
        )
        store.save()
        return true
    }
}

// MARK: – Section block (header + items)

struct SectionBlock: View {
    @Binding var section: TodoSection
    @Binding var list: TodoList
    let store:    TodoStore
    let settings: AppSettings

    let onMoveItem:          ([String], UUID, UUID) -> Bool
    let onMoveItemToSection: ([String], UUID)        -> Bool
    let onReorderSection:    (String,  UUID)         -> Bool

    var body: some View {
        let isCompleted = !section.items.isEmpty && section.items.allSatisfy { $0.isDone }

        if !section.name.isEmpty {
            SectionHeaderRow(
                name:        section.name,
                fontSize:    settings.sectionFontSize,
                canDelete:   list.sections.count > 1,
                isCompleted: isCompleted,
                onRename: { newName in
                    if let si = list.sections.firstIndex(where: { $0.id == section.id }) {
                        list.sections[si].name = newName
                        store.save()
                    }
                },
                onDelete: {
                    guard let si = list.sections.firstIndex(where: { $0.id == section.id }) else { return }
                    let orphans = list.sections[si].items
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                        list.sections.remove(at: si)
                        if !orphans.isEmpty, !list.sections.isEmpty {
                            list.sections[0].items.insert(contentsOf: orphans, at: 0)
                        }
                    }
                    store.save()
                }
            )
            .draggable("section:\(section.id.uuidString)")
            .dropDestination(for: String.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                if payload.hasPrefix("section:") {
                    return onReorderSection(payload, section.id)
                } else {
                    return onMoveItemToSection(payloads, section.id)
                }
            }
        }

        ForEach($section.items) { $item in
            let sectionID = section.id
            let itemID    = item.id
            TodoItemRow(item: $item) {
                guard let si = list.sections.firstIndex(where: { $0.id == sectionID }),
                      let ii = list.sections[si].items.firstIndex(where: { $0.id == itemID })
                else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                    list.sections[si].items.remove(at: ii)
                }
                store.save()
            }
            .transition(.asymmetric(
                insertion: .push(from: .bottom).combined(with: .opacity),
                removal:   .opacity
            ))
            .draggable("\(section.id.uuidString):\(item.id.uuidString)")
            .dropDestination(for: String.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                if payload.hasPrefix("section:") {
                    return onReorderSection(payload, section.id)
                } else {
                    return onMoveItem(payloads, section.id, item.id)
                }
            }
        }

        // Drop zone at the end of each section so items can be appended.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: section.items.isEmpty ? 24 : 8)
            .dropDestination(for: String.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                if payload.hasPrefix("section:") {
                    return onReorderSection(payload, section.id)
                } else {
                    return onMoveItemToSection(payloads, section.id)
                }
            }
    }
}

// MARK: – Section header

struct SectionHeaderRow: View {
    let name:        String
    let fontSize:    Double
    let canDelete:   Bool
    let isCompleted: Bool
    let onRename:    (String) -> Void
    let onDelete:    () -> Void

    @State private var isRenaming = false
    @State private var draft      = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            if isRenaming {
                TextField("Section name", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: CGFloat(fontSize), weight: .semibold))
                    .focused($focused)
                    .onAppear      { draft = name; focused = true }
                    .onSubmit      { commit() }
                    .onExitCommand { isRenaming = false }
            } else {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: CGFloat(fontSize) - 1))
                        .foregroundStyle(.green.opacity(0.75))
                }
                Text(name.uppercased())
                    .font(.system(size: CGFloat(fontSize), weight: .semibold))
                    .foregroundStyle(isCompleted ? Color.secondary.opacity(0.5) : Color.secondary)
                    .strikethrough(isCompleted, color: .secondary)
                    .onTapGesture(count: 2) { isRenaming = true }
            }
            Spacer()
        }
        .onChange(of: focused) { _, f in if !f && isRenaming { commit() } }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.secondary.opacity(0.07))
        .contextMenu {
            Button("Rename") { isRenaming = true }
            if canDelete {
                Divider()
                Button("Delete Section", role: .destructive) { onDelete() }
            }
        }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { onRename(trimmed) }
        isRenaming = false
    }
}

// MARK: – Item row

struct TodoItemRow: View {
    @EnvironmentObject var store:    TodoStore
    @EnvironmentObject var settings: AppSettings
    @Binding var item: TodoItem
    let onDelete: () -> Void

    @State private var isHovered         = false
    @State private var isEditing         = false
    @State private var isNewItem         = false
    @State private var draft             = ""
    @State private var showingIconPicker = false
    @FocusState private var editFocused: Bool

    private var showHoverControls: Bool { isHovered || showingIconPicker }

    // Detect bare URLs so they can be tapped to open in the default browser.
    private var itemURL: URL? {
        let text = item.text.trimmingCharacters(in: .whitespaces).lowercased()
        guard text.hasPrefix("http://") || text.hasPrefix("https://") else { return nil }
        return URL(string: item.text.trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                item.isDone.toggle()
                store.save()
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: CGFloat(settings.fontSize)))
                    .foregroundStyle(item.isDone ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            if !item.icon.isEmpty {
                Text(item.icon).font(.system(size: CGFloat(settings.fontSize)))
            }

            if isEditing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: CGFloat(settings.fontSize)))
                    .focused($editFocused)
                    .onAppear      { draft = item.text; editFocused = true }
                    .onSubmit      { applyEdit() }
                    .onExitCommand {
                        if isNewItem { onDelete() }
                        isEditing = false
                    }
                    .onChange(of: editFocused) { _, f in if !f && isEditing { applyEdit() } }
            } else if let url = itemURL {
                Text(item.text)
                    .font(.system(size: CGFloat(settings.fontSize)))
                    .foregroundStyle(.blue)
                    .underline()
                    .strikethrough(item.isDone, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) { isEditing = true }
                    .onTapGesture(count: 1) { NSWorkspace.shared.open(url) }
            } else {
                Text(item.text)
                    .font(.system(size: CGFloat(settings.fontSize)))
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .strikethrough(item.isDone, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) { isEditing = true }
            }

            if showHoverControls && !isEditing {
                Button { showingIconPicker = true } label: {
                    Image(systemName: item.icon.isEmpty ? "face.smiling" : "face.smiling.fill")
                        .font(.system(size: max(10, CGFloat(settings.fontSize) - 3)))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingIconPicker, arrowEdge: .bottom) {
                    EmojiPickerView { emoji in
                        item.icon = emoji
                        store.save()
                        showingIconPicker = false
                    }
                }

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: max(10, CGFloat(settings.fontSize) - 3)))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .onAppear {
            // Auto-enter edit mode for items created via the Add Item button.
            if store.pendingEditItemID == item.id {
                store.pendingEditItemID = nil
                isEditing = true
                isNewItem = true
            }
        }
    }

    private var rowBackground: Color {
        if isEditing { return Color.accentColor.opacity(0.09) }
        if isHovered { return Color.primary.opacity(0.05) }
        return .clear
    }

    private func applyEdit() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        // Delete the row if the user left it blank (only for newly created items).
        if text.isEmpty {
            isEditing = false
            editFocused = false
            onDelete()
            return
        }
        item.text = text
        isEditing   = false
        editFocused = false
        isNewItem   = false
        store.save()
    }
}
