// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI

struct EmojiPickerView: View {
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.fixed(40), spacing: 4), count: 6)

    private let emojis = [
        // Work & productivity
        "📋","📝","📌","📎","🗂️","📁","📅","🗓️",
        "💼","🖥️","💻","⌨️","🖱️","📱","☎️","📞",
        "📧","📨","📩","✉️","📮","📬","📤","📥",
        // Learning & ideas
        "📚","📖","🎓","💡","🔬","🔭","🧪","🧠",
        // Personal & home
        "🏠","🏡","🛋️","🍽️","🛒","🧹","🔑","🪴",
        // Health & fitness
        "🏋️","🏃","🧘","💊","🩺","🥗","💪","🚴",
        // Finance
        "💰","💳","💵","📈","📉","🏦","🤑","💹",
        // Creative
        "🎨","✏️","🖊️","📷","🎬","🎵","🎸","🎤",
        // Travel & places
        "✈️","🚗","🚂","🏖️","🗺️","📍","🏔️","🌍",
        // Food
        "☕","🍕","🍔","🍜","🍎","🥑","🍰","🥂",
        // Nature & weather
        "🌟","⭐","🌈","☀️","🌙","❄️","🌿","🌸",
        // Symbols & flags
        "🔴","🟠","🟡","🟢","🔵","🟣","⚫","⚪",
        "✅","❌","⚠️","🔥","⚡","🚀","🎯","🏆",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Choose Icon")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("Remove") { onSelect("") }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            onSelect(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 22))
                                .frame(width: 40, height: 40)
                                .background(Color.primary.opacity(0.05),
                                            in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(height: 240)
        }
        .padding(12)
        .frame(width: 296)
    }
}
