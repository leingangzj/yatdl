// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import Foundation

struct TodoList: Identifiable, Codable {
    var id    = UUID()
    var name:  String
    var icon:  String     = ""
    var items: [TodoItem] = []
}
