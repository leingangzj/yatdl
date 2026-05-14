// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI

struct BottomToolbarView: View {
    @EnvironmentObject var store: TodoStore

    var body: some View {
        HStack(spacing: 14) {
            Button(action: toggleDisplayMode) {
                Image(systemName: store.displayMode == .dropFromMenubar
                    ? "menubar.arrow.down.rectangle"
                    : "sidebar.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(store.displayMode == .dropFromMenubar
                ? "Switch to slide from right"
                : "Switch to drop from menubar")

            Spacer()

            // isPinned is not persisted — it intentionally resets on relaunch
            Button(action: { store.isPinned.toggle() }) {
                Image(systemName: store.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundStyle(store.isPinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(store.isPinned ? "Unpin window" : "Pin window (keep visible)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func toggleDisplayMode() {
        store.displayMode = store.displayMode == .dropFromMenubar ? .slideFromRight : .dropFromMenubar
        store.save()
    }

}
