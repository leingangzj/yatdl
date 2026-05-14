// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI

@main
struct YATDLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // Settings scene keeps the SwiftUI lifecycle happy without opening a window
        Settings { EmptyView() }
    }
}
