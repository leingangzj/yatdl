// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Foundation
import ServiceManagement

enum AppearanceMode: String, CaseIterable {
    case system, light, dark
    var label: String { rawValue.capitalized }
}

enum TabPosition: String, CaseIterable {
    case top, left, bottom
    var label: String { rawValue.capitalized }
}

final class AppSettings: ObservableObject {
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    @Published var sectionFontSize: Double {
        didSet { UserDefaults.standard.set(sectionFontSize, forKey: "sectionFontSize") }
    }
    @Published var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }
    @Published var tabPosition: TabPosition {
        didSet { UserDefaults.standard.set(tabPosition.rawValue, forKey: "tabPosition") }
    }
    @Published var launchAtLogin: Bool

    init() {
        self.fontSize        = UserDefaults.standard.object(forKey: "fontSize")        as? Double ?? 13
        self.sectionFontSize = UserDefaults.standard.object(forKey: "sectionFontSize") as? Double ?? 11
        self.appearance      = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearance")  ?? "") ?? .system
        self.tabPosition     = TabPosition(rawValue:    UserDefaults.standard.string(forKey: "tabPosition") ?? "") ?? .top
        self.launchAtLogin   = SMAppService.mainApp.status == .enabled
    }
}
