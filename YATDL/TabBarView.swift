// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var store: TodoStore
    @State private var isAddingTab = false
    @State private var newTabName  = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(store.lists) { list in
                        TabChip(list: list)
                    }
                }
                .padding(.horizontal, 8)
            }

            Divider().frame(height: 18)

            if isAddingTab {
                TextField("Name", text: $newTabName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 76)
                    .focused($focused)
                    .padding(.horizontal, 8)
                    .onAppear     { focused = true }
                    .onSubmit     { commit() }
                    .onExitCommand { cancel() }
            } else {
                Button { isAddingTab = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
        }
        .frame(height: 36)
    }

    private func commit() {
        let name = newTabName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancel(); return }
        let list = TodoList(name: name)
        store.lists.append(list)
        store.selectedListID = list.id
        newTabName  = ""
        isAddingTab = false
        store.save()
    }

    private func cancel() {
        newTabName  = ""
        isAddingTab = false
    }
}

struct TabChip: View {
    @EnvironmentObject var store: TodoStore
    let list: TodoList
    var isSelected: Bool { store.selectedListID == list.id }

    var body: some View {
        Button { store.selectedListID = list.id } label: {
            Text(list.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected ? Color.accentColor.opacity(0.18) : .clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
    }
}
