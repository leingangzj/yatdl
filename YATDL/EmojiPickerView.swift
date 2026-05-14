// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI

struct EmojiPickerView: View {
    let onSelect: (String) -> Void

    private let emojis = [
        "📋","📝","🏠","💼","🛒","🎯","💡","📚",
        "🏋️","🎮","🌟","⭐","🔴","🟡","🟢","🔵",
        "✅","📌","🔥","⚡","🚀","📎","💊","🍎",
        "🏃","📞","💻","🎵","🎨","🔧","📅","🌈",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Icon")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("None") { onSelect("") }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 8), spacing: 2) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(emoji) { onSelect(emoji) }
                        .font(.system(size: 18))
                        .buttonStyle(.plain)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(10)
        .frame(width: 272)
    }
}
