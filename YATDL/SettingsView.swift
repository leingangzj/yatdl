// YATDL — Yet Another To-Do List
// Author: Zac Leingang

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store:    TodoStore

    @State private var cliStatus: CLIStatus = .unknown

    enum CLIStatus {
        case unknown, installed, notInstalled, installing, failed
        var label: String {
            switch self {
            case .unknown:      return "Checking…"
            case .installed:    return "Installed ✓"
            case .notInstalled: return "Not installed"
            case .installing:   return "Installing…"
            case .failed:       return "Failed — check permissions"
            }
        }
        var color: Color {
            switch self {
            case .installed: return .green
            case .failed:    return .red
            default:         return .secondary
            }
        }
    }

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

            // ── CLI ─────────────────────────────────────────────────────────
            GroupBox("Command-Line Tool") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Installs `yatdl` to /usr/local/bin — use the CLI and TUI from any terminal.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button("Install CLI Tool…") { installCLI() }
                            .disabled(cliStatus == .installing)

                        Text(cliStatus.label)
                            .font(.system(size: 11))
                            .foregroundStyle(cliStatus.color)
                    }
                }
                .padding(10)
            }
            .onAppear { checkCLI() }

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

    // MARK: – CLI install

    private func checkCLI() {
        let installed = FileManager.default.fileExists(atPath: "/usr/local/bin/yatdl")
        cliStatus = installed ? .installed : .notInstalled
    }

    private func installCLI() {
        guard let src = Bundle.main.url(forResource: "yatdl", withExtension: nil) else {
            cliStatus = .failed; return
        }
        cliStatus = .installing
        let srcPath = src.path
        let script  = "do shell script \"install -m 755 \(srcPath) /usr/local/bin/yatdl\" with administrator privileges"
        DispatchQueue.global(qos: .userInitiated).async {
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            DispatchQueue.main.async {
                cliStatus = err == nil ? .installed : .failed
            }
        }
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
