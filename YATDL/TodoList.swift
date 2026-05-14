// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Foundation

struct TodoSection: Identifiable, Codable {
    var id    = UUID()
    var name: String
    var items: [TodoItem] = []

    init(name: String, items: [TodoItem] = []) {
        self.name  = name
        self.items = items
    }

    private enum CodingKeys: String, CodingKey { case id, name, items }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id    = (try? c.decode(UUID.self,       forKey: .id))    ?? UUID()
        name  = (try? c.decode(String.self,     forKey: .name))  ?? ""
        items = (try? c.decode([TodoItem].self, forKey: .items)) ?? []
    }
}

struct TodoList: Identifiable, Codable {
    var id       = UUID()
    var name:    String
    var icon:    String         = ""
    var sections: [TodoSection] = []

    init(name: String) {
        self.name     = name
        self.sections = [TodoSection(name: "")]
    }

    private enum CodingKeys: String, CodingKey { case id, name, icon, sections }

    // Separate key set used only during decode for migrating the old flat-items format.
    private enum LegacyCodingKeys: String, CodingKey { case items }

    init(from decoder: Decoder) throws {
        let c  = try  decoder.container(keyedBy: CodingKeys.self)
        let lc = try? decoder.container(keyedBy: LegacyCodingKeys.self)
        id   = (try? c.decode(UUID.self,   forKey: .id))   ?? UUID()
        name = try  c.decode(String.self,  forKey: .name)
        icon = (try? c.decode(String.self, forKey: .icon)) ?? ""
        if let legacyItems = try? lc?.decode([TodoItem].self, forKey: .items) {
            sections = [TodoSection(name: "", items: legacyItems)]
        } else {
            let decoded = (try? c.decode([TodoSection].self, forKey: .sections)) ?? []
            sections = decoded.isEmpty ? [TodoSection(name: "")] : decoded
        }
    }
}
