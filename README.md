# YATDL — Yet Another To-Do List

A lightweight, native macOS menubar to-do app with a companion CLI. Built with SwiftUI + AppKit, arm64 native, targeting macOS 14+. No Xcode required to build.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Features

### Panel & Navigation

| Feature | Detail |
|---|---|
| **Menubar-only** | Runs entirely from the menu bar — no Dock icon, no Cmd+Tab entry |
| **Global hotkey** | **Option+Space** opens or closes the panel from anywhere |
| **Drop-down mode** | Panel drops down directly below the menubar icon |
| **Slide-in mode** | Panel slides in from the right edge and nudges open windows aside |
| **Hot-edge hover** | In slide-in mode, hovering near the right edge opens the panel without clicking |
| **Mode toggle** | Switch between drop-down and slide-in from the bottom toolbar |
| **Pin mode** | Keep the panel open regardless of outside clicks |
| **Appearance** | System, Light, or Dark mode — switchable in Settings |

### Lists (Tabs)

| Feature | Detail |
|---|---|
| **Up to 3 lists** | Create up to three named lists (tabs); tabs fill the bar width evenly |
| **Tab positions** | Top, Bottom, or Left sidebar — switchable in Settings |
| **Inline create** | Click **Add Tab** to create a new list and immediately rename it in place |
| **Rename** | Double-click or right-click → Rename |
| **Icons** | Right-click → Set Icon to assign an emoji to any tab |
| **Drag to reorder** | Drag tabs to rearrange their order |
| **Delete with confirmation** | Right-click → Delete List shows a confirmation before removing |

### Sections

| Feature | Detail |
|---|---|
| **Sections within lists** | Divide any list into named sections |
| **Inline create** | Click **Add Section** to add a section at the bottom with inline rename |
| **Rename** | Double-click or right-click → Rename |
| **Completion indicator** | Green ✓ and strikethrough on a section header when all its items are done |
| **Drag to reorder** | Drag section headers above, below, or between items |
| **Delete** | Right-click → Delete Section; orphaned items fold into the first section |

### Items

| Feature | Detail |
|---|---|
| **Inline create** | Click **Add Item** to add a blank item at the bottom and immediately edit it |
| **Check/uncheck** | Click the circle to toggle done; strikethrough applied automatically |
| **Inline edit** | Double-click any item to edit it in place |
| **Click-away saves** | Clicking anywhere outside an active edit field commits the change |
| **Icons** | Hover a row and click the smiley to assign an emoji icon |
| **URL items** | Paste any `http://` or `https://` URL — single-click opens it in your default browser |
| **Delete** | Hover a row to reveal the × button |
| **Drag to reorder** | Drag items within or between sections |

### Settings

| Feature | Detail |
|---|---|
| **Font size** | Adjustable item font size (11–20 pt) with live preview |
| **Section font size** | Separate size control for section headers (9–16 pt) |
| **Appearance** | System / Light / Dark |
| **Tab position** | Top / Left / Bottom |
| **Launch at Login** | Registers with `SMAppService` — no login items kludge |
| **CSV export** | Export the current list or all lists to a CSV with List, Section, Item, Done, and Created At columns |

### CLI (`yatdl`)

```
yatdl                 show current list
yatdl lists           show all lists
yatdl use <name>      switch to a list
yatdl add <text>      add item to current list
yatdl done <num>      mark item done
yatdl undo <num>      mark item not done
yatdl rm <num>        remove item
yatdl newtab <name>   create a new list
yatdl rmtab <name>    delete a list
yatdl -i              interactive REPL with ANSI colour
yatdl help            show help
```

### Bidirectional Sync

Both the app and CLI read and write the same file:

```
~/Library/Application Support/YATDL/data.json
```

The GUI watches that file with a **kqueue-backed DispatchSource** (no polling, no FSEvents overhead). Any change made in the CLI appears in the GUI within milliseconds.

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (arm64)
- Swift toolchain (Xcode Command Line Tools — `xcode-select --install`)

---

## Build

### GUI App

```bash
make app
```

Compiles all Swift sources with `swiftc` and produces `.build/YATDL.app`.

To install to `/Applications`:

```bash
make install-app
```

### CLI

```bash
make install
```

Compiles `cli/main.swift` and installs it to `/usr/local/bin/yatdl`.

### Clean

```bash
make clean
```

---

## Hotkey

The global hotkey is **Option+Space**, registered via the Carbon Event Manager (`RegisterEventHotKey`). This predates the Input Monitoring permission system — no special entitlement or user approval required.

---

## Data Format

```json
{
  "lists": [
    {
      "id": "…",
      "name": "Personal",
      "icon": "📋",
      "sections": [
        {
          "id": "…",
          "name": "",
          "items": [
            { "id": "…", "text": "Buy groceries", "icon": "", "isDone": false, "createdAt": "…" }
          ]
        },
        {
          "id": "…",
          "name": "Someday",
          "items": []
        }
      ]
    }
  ],
  "selectedListID": "…",
  "displayMode": "dropFromMenubar",
  "isPinned": false
}
```

Written atomically on every mutation. Backward-compatible with the original flat `items` format.

---

## Project Structure

```
YATDL/
  YATDLApp.swift          App entry point (@main, SwiftUI lifecycle)
  AppDelegate.swift       NSStatusItem, hotkey, panel lifecycle, settings window
  AppSettings.swift       Persisted preferences (UserDefaults)
  PanelController.swift   NSPanel management, positioning, hot-edge hover
  HotkeyManager.swift     Carbon RegisterEventHotKey wrapper
  PanelAction.swift       EnvironmentObject bridge for Escape-to-close
  TodoStore.swift         ObservableObject — state, persistence, file watcher
  FileWatcher.swift       kqueue DispatchSource watching data.json
  TodoItem.swift          Item model
  TodoList.swift          List + Section models with legacy migration
  ContentView.swift       Root SwiftUI view; tab-position layout switch
  TabBarView.swift        Horizontal and vertical tab bars + chip views
  TodoListView.swift      Scroll view, section blocks, item rows
  BottomToolbarView.swift Display-mode toggle and pin button
  EmojiPickerView.swift   Emoji icon picker popover
  SettingsView.swift      Settings panel with CSV export
  Info.plist              LSUIElement=YES, bundle metadata
  AppIcon.icns            App icon
cli/
  main.swift              Self-contained CLI (no shared framework)
Makefile                  make app / cli / install-app / install / clean
LICENSE                   MIT License
```

---

## License

MIT — see [LICENSE](LICENSE).

## Author

**Zac Leingang** — leingangzj@gmail.com — [github.com/leingangzj/yatdl](https://github.com/leingangzj/yatdl)
