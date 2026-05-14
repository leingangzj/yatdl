// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI

struct TodoListView: View {
    @EnvironmentObject var store: TodoStore
    @Binding var list: TodoList
    @State private var newText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($list.items) { $item in
                        TodoItemRow(item: $item) {
                            list.items.removeAll { $0.id == item.id }
                            store.save()
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Add item…", text: $newText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(addItem)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func addItem() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        list.items.append(TodoItem(text: text))
        newText = ""
        store.save()
    }
}

struct TodoItemRow: View {
    @EnvironmentObject var store: TodoStore
    @Binding var item: TodoItem
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var draft     = ""

    var body: some View {
        HStack(spacing: 8) {
            Button {
                item.isDone.toggle()
                store.save()
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(item.isDone ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onAppear     { draft = item.text }
                    .onSubmit     { applyEdit() }
                    .onExitCommand { isEditing = false }
            } else {
                Text(item.text)
                    .font(.system(size: 13))
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .strikethrough(item.isDone, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Double-click to edit, matching standard macOS convention
                    .onTapGesture(count: 2) { isEditing = true }
            }

            if isHovered && !isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.05) : .clear)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    private func applyEdit() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty { item.text = text }
        isEditing = false
        store.save()
    }
}
