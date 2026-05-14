// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Foundation

// Passed as an EnvironmentObject so SwiftUI views can trigger panel actions
// (e.g. Escape key dismisses the panel) without holding a direct reference
// to PanelController.
final class PanelAction: ObservableObject {
    var hidePanel: (() -> Void)?
}
