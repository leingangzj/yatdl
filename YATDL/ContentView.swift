// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store:  TodoStore
    @EnvironmentObject var action: PanelAction

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()
            Divider()
            if let idx = store.lists.firstIndex(where: { $0.id == store.selectedListID }) {
                TodoListView(list: $store.lists[idx])
                    .frame(maxHeight: .infinity)
            }
            Divider()
            BottomToolbarView()
        }
        // Width is fixed; height is driven by the panel (drop=480, slide=full screen)
        .frame(width: PanelController.width)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // Escape key hides the panel (routed back via PanelAction)
        .onExitCommand { action.hidePanel?() }
    }
}
