// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var store:    TodoStore
    @EnvironmentObject var action:   PanelAction
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Group {
            switch settings.tabPosition {
            case .top:
                VStack(spacing: 0) {
                    TabBarView()
                    Divider()
                    listContent
                    Divider()
                    BottomToolbarView()
                }
            case .bottom:
                VStack(spacing: 0) {
                    listContent
                    Divider()
                    TabBarView()
                    Divider()
                    BottomToolbarView()
                }
            case .left:
                HStack(spacing: 0) {
                    SideTabBarView()
                    Divider()
                    VStack(spacing: 0) {
                        listContent
                        Divider()
                        BottomToolbarView()
                    }
                }
            }
        }
        .frame(width: PanelController.width)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .preferredColorScheme(colorScheme)
        .onExitCommand { action.hidePanel?() }
        .simultaneousGesture(TapGesture().onEnded {
            NSApp.keyWindow?.makeFirstResponder(nil)
        })
    }

    @ViewBuilder
    private var listContent: some View {
        if let idx = store.lists.firstIndex(where: { $0.id == store.selectedListID }) {
            TodoListView(list: $store.lists[idx])
                .frame(maxHeight: .infinity)
        }
    }

    private var colorScheme: ColorScheme? {
        switch settings.appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
