// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI

// Maximum number of lists allowed at once.
let maxListCount = 3

// MARK: – Horizontal tab bar (top / bottom positions)

struct TabBarView: View {
    @EnvironmentObject var store: TodoStore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(store.lists) { list in
                TabChip(listID: list.id)
                    .frame(maxWidth: .infinity)
                    .transition(.asymmetric(
                        insertion: .push(from: .trailing).combined(with: .opacity),
                        removal:   .opacity
                    ))
                    .draggable(list.id.uuidString)
                    .dropDestination(for: String.self) { ids, _ in
                        guard let draggedID = ids.first,
                              let from = store.lists.firstIndex(where: { $0.id.uuidString == draggedID }),
                              let to   = store.lists.firstIndex(where: { $0.id == list.id }),
                              from != to else { return false }
                        store.lists.move(fromOffsets: IndexSet([from]), toOffset: to > from ? to + 1 : to)
                        store.save()
                        return true
                    }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: store.lists.count)
    }
}

// MARK: – Vertical tab bar (left position)

struct SideTabBarView: View {
    @EnvironmentObject var store: TodoStore

    var body: some View {
        VStack(spacing: 2) {
            ForEach(store.lists) { list in
                SideTabChip(listID: list.id)
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).combined(with: .opacity),
                        removal:   .opacity
                    ))
                    .draggable(list.id.uuidString)
                    .dropDestination(for: String.self) { ids, _ in
                        guard let draggedID = ids.first,
                              let from = store.lists.firstIndex(where: { $0.id.uuidString == draggedID }),
                              let to   = store.lists.firstIndex(where: { $0.id == list.id }),
                              from != to else { return false }
                        store.lists.move(fromOffsets: IndexSet([from]), toOffset: to > from ? to + 1 : to)
                        store.save()
                        return true
                    }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .frame(width: 70)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: store.lists.count)
    }
}

// MARK: – Horizontal chip

struct TabChip: View {
    @EnvironmentObject var store:    TodoStore
    @EnvironmentObject var settings: AppSettings
    let listID: UUID

    @State private var showingIconPicker = false
    @State private var isRenaming        = false
    @State private var renameDraft       = ""
    @State private var showDeleteConfirm = false
    @FocusState private var renameFocused: Bool

    private var listName: String { store.lists.first(where: { $0.id == listID })?.name ?? "" }
    private var listIcon: String { store.lists.first(where: { $0.id == listID })?.icon ?? "" }

    var isSelected: Bool { store.selectedListID == listID }
    private var chipFontSize: CGFloat { min(CGFloat(settings.fontSize), 13) }

    private var chipBackground: Color {
        isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.07)
    }

    var body: some View {
        chipContent
            .popover(isPresented: $showingIconPicker, arrowEdge: .bottom) {
                EmojiPickerView { emoji in
                    if let idx = store.lists.firstIndex(where: { $0.id == listID }) {
                        store.lists[idx].icon = emoji
                        store.save()
                    }
                    showingIconPicker = false
                }
            }
            .contextMenu {
                Button("Rename")    { isRenaming = true }
                Button("Set Icon…") { showingIconPicker = true }
                if store.lists.count > 1 {
                    Divider()
                    Button("Delete List", role: .destructive) { showDeleteConfirm = true }
                }
            }
            .confirmationDialog("Delete \"\(listName)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteList() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove the list and all its items.")
            }
            .onAppear {
                if store.pendingRenameListID == listID {
                    store.pendingRenameListID = nil
                    isRenaming = true
                }
            }
    }

    @ViewBuilder
    private var chipContent: some View {
        if isRenaming {
            TextField("", text: $renameDraft)
                .textFieldStyle(.plain)
                .font(.system(size: chipFontSize, weight: .semibold))
                .frame(maxWidth: .infinity)
                .focused($renameFocused)
                .onAppear      { renameDraft = listName; renameFocused = true }
                .onSubmit      { commitRename() }
                .onExitCommand { isRenaming = false }
                .onChange(of: renameFocused) { _, f in if !f && isRenaming { commitRename() } }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
        } else {
            Button { store.selectedListID = listID } label: {
                HStack(spacing: 4) {
                    if !listIcon.isEmpty {
                        Text(listIcon).font(.system(size: chipFontSize))
                    }
                    Text(listName)
                        .font(.system(size: chipFontSize, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(chipBackground, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }

    private func commitRename() {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let idx = store.lists.firstIndex(where: { $0.id == listID }) {
            store.lists[idx].name = trimmed
            store.save()
        }
        isRenaming = false
    }

    private func deleteList() {
        guard let idx = store.lists.firstIndex(where: { $0.id == listID }) else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            store.lists.remove(at: idx)
            if !store.lists.contains(where: { $0.id == store.selectedListID }) {
                store.selectedListID = store.lists[max(0, idx - 1)].id
            }
        }
        store.save()
    }
}

// MARK: – Vertical chip (left sidebar)

struct SideTabChip: View {
    @EnvironmentObject var store:    TodoStore
    @EnvironmentObject var settings: AppSettings
    let listID: UUID

    @State private var showingIconPicker = false
    @State private var isRenaming        = false
    @State private var renameDraft       = ""
    @State private var showDeleteConfirm = false
    @FocusState private var renameFocused: Bool

    private var listName: String { store.lists.first(where: { $0.id == listID })?.name ?? "" }
    private var listIcon: String { store.lists.first(where: { $0.id == listID })?.icon ?? "" }

    var isSelected: Bool { store.selectedListID == listID }

    private var chipBackground: Color {
        isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.07)
    }

    var body: some View {
        chipContent
            .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
                EmojiPickerView { emoji in
                    if let idx = store.lists.firstIndex(where: { $0.id == listID }) {
                        store.lists[idx].icon = emoji
                        store.save()
                    }
                    showingIconPicker = false
                }
            }
            .contextMenu {
                Button("Rename")    { isRenaming = true }
                Button("Set Icon…") { showingIconPicker = true }
                if store.lists.count > 1 {
                    Divider()
                    Button("Delete List", role: .destructive) { showDeleteConfirm = true }
                }
            }
            .confirmationDialog("Delete \"\(listName)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteList() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove the list and all its items.")
            }
            .onAppear {
                if store.pendingRenameListID == listID {
                    store.pendingRenameListID = nil
                    isRenaming = true
                }
            }
    }

    @ViewBuilder
    private var chipContent: some View {
        if isRenaming {
            TextField("", text: $renameDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity)
                .focused($renameFocused)
                .onAppear      { renameDraft = listName; renameFocused = true }
                .onSubmit      { commitRename() }
                .onExitCommand { isRenaming = false }
                .onChange(of: renameFocused) { _, f in if !f && isRenaming { commitRename() } }
                .multilineTextAlignment(.center)
        } else {
            Button { store.selectedListID = listID } label: {
                VStack(spacing: 3) {
                    if !listIcon.isEmpty {
                        Text(listIcon).font(.system(size: 16))
                    } else {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    Text(listName)
                        .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 58)
                .padding(.vertical, 6)
                .background(chipBackground, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }

    private func commitRename() {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let idx = store.lists.firstIndex(where: { $0.id == listID }) {
            store.lists[idx].name = trimmed
            store.save()
        }
        isRenaming = false
    }

    private func deleteList() {
        guard let idx = store.lists.firstIndex(where: { $0.id == listID }) else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            store.lists.remove(at: idx)
            if !store.lists.contains(where: { $0.id == store.selectedListID }) {
                store.selectedListID = store.lists[max(0, idx - 1)].id
            }
        }
        store.save()
    }
}
