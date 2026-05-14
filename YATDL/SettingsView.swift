// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store:    TodoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Appearance ──────────────────────────────────────────────────
            GroupBox("Appearance") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Mode")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $settings.appearance) {
                            ForEach(AppearanceMode.allCases, id: \.self) {
                                Text($0.label).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    HStack {
                        Text("Font Size")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $settings.fontSize, in: 11...20, step: 1)
                        Text("\(Int(settings.fontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }

                    HStack {
                        Text("Section Size")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $settings.sectionFontSize, in: 9...16, step: 1)
                        Text("\(Int(settings.sectionFontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }

                    HStack {
                        Text("Tabs")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $settings.tabPosition) {
                            ForEach(TabPosition.allCases, id: \.self) {
                                Text($0.label).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Live preview
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.system(size: CGFloat(settings.fontSize)))
                            .foregroundStyle(.secondary)
                        Text("📌")
                            .font(.system(size: CGFloat(settings.fontSize)))
                        Text("Sample todo item")
                            .font(.system(size: CGFloat(settings.fontSize)))
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(10)
            }

            // ── System ──────────────────────────────────────────────────────
            GroupBox("System") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                        .onChange(of: settings.launchAtLogin) { _, newValue in
                            do {
                                if newValue { try SMAppService.mainApp.register()   }
                                else        { try SMAppService.mainApp.unregister() }
                            } catch {
                                // Revert to actual state if registration failed
                                settings.launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                }
                .padding(10)
            }

            // ── Export ──────────────────────────────────────────────────────
            GroupBox("Export to CSV") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exports list name, item text, status, and creation date.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button("Export Current List") { exportCSV(all: false) }
                        Button("Export All Lists")    { exportCSV(all: true)  }
                    }
                }
                .padding(10)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 400, alignment: .topLeading)
    }

    // MARK: – CSV export

    private func exportCSV(all: Bool) {
        let lists = all
            ? store.lists
            : store.lists.filter { $0.id == store.selectedListID }

        guard !lists.isEmpty else { return }

        var csv = "List,Section,Item,Done,Created At\n"
        let fmt  = ISO8601DateFormatter()

        for list in lists {
            for section in list.sections {
                let sectionLabel = section.name.isEmpty ? "" : section.name
                for item in section.items {
                    let row = [list.name, sectionLabel, item.text, item.isDone ? "Yes" : "No", fmt.string(from: item.createdAt)]
                        .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                        .joined(separator: ",")
                    csv += row + "\n"
                }
            }
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes  = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = all ? "yatdl-all-lists.csv" : "\(lists.first?.name ?? "list").csv"

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
