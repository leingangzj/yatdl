// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TodoStore

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()
            Divider()
            // Drive the list view off the index so the binding propagates
            // writes back into the store array rather than a copied value.
            if let idx = store.lists.firstIndex(where: { $0.id == store.selectedListID }) {
                TodoListView(list: $store.lists[idx])
            }
            Divider()
            BottomToolbarView()
        }
        .frame(width: PanelController.width, height: PanelController.height)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
