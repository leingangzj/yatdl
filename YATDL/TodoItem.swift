// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id        = UUID()
    var text:     String
    var icon:     String = ""
    var isDone:   Bool   = false
    var createdAt: Date  = Date()

    init(text: String) {
        self.text = text
    }

    // Custom decode so old JSON without icon key still loads correctly.
    private enum CodingKeys: String, CodingKey {
        case id, text, icon, isDone, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = (try? c.decode(UUID.self,   forKey: .id))        ?? UUID()
        text      = try  c.decode(String.self,  forKey: .text)
        icon      = (try? c.decode(String.self, forKey: .icon))      ?? ""
        isDone    = (try? c.decode(Bool.self,   forKey: .isDone))    ?? false
        createdAt = (try? c.decode(Date.self,   forKey: .createdAt)) ?? Date()
    }
}
