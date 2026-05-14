// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id        = UUID()
    var text:     String
    var icon:     String = ""
    var isDone:   Bool   = false
    var createdAt: Date  = Date()
}
