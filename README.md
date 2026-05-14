# YATDL — Yet Another To-Do List

A lightweight, native macOS menubar todo app with a companion CLI. Built with SwiftUI + AppKit, arm64 native, targeting macOS 14+.

---

## Features

### Menubar App

| Feature | Detail |
|---|---|
| **Menubar-only** | Runs entirely from the menu bar — no Dock icon, no Cmd+Tab entry |
| **Global hotkey** | **Option+Space** opens or closes the panel from anywhere on screen |
| **Drop-down mode** | Panel drops down below the menubar icon (default) |
| **Slide-in mode** | Panel slides in from the right edge of the screen |
| **Mode toggle** | Switch between drop-down and slide-in from the bottom toolbar |
| **Pin mode** | Keep the panel visible regardless of outside clicks |
| **Multiple lists** | Tab bar lets you create, switch, and delete named lists |
| **Add items** | Inline input at the bottom of each list — press Enter to add |
| **Check/uncheck** | Click the circle to mark items done; strikethrough applied |
| **Delete items** | Hover a row to reveal the × button |
| **Inline edit** | Double-click any item to edit it in place |
| **Persistence** | Every change is saved immediately to disk |
| **GUI↔CLI sync** | A kqueue file watcher refreshes the GUI the moment the CLI writes |
| **arm64 native** | Compiled for Apple Silicon — no Rosetta, no overhead |

### CLI (`yatdl`)

```
yatdl                 show current list
yatdl lists           show all lists / tabs
yatdl use <name>      switch to a list
yatdl add <text>      add item to current list
yatdl done <num>      mark item done
yatdl undo <num>      mark item not done
yatdl rm <num>        remove item
yatdl newtab <name>   create a new list
yatdl rmtab <name>    delete a list
yatdl -i              interactive REPL (with ANSI colour)
yatdl help            show help
```

Interactive mode (`yatdl -i`) gives you a persistent prompt with the current list name, so you can chain commands without re-invoking.

### Bidirectional Sync

Both the app and the CLI read and write the same file:

```
~/Library/Application Support/YATDL/data.json
```

The GUI uses a **kqueue-backed DispatchSource** (no polling, no FSEvents overhead) to watch that file. Any change made in the CLI appears in the GUI within milliseconds — no restart required.

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (arm64)
- Xcode 15+ (to build the GUI app)

---

## Build

### GUI App

Open `YATDL.xcodeproj` in Xcode and press **⌘B**, or from the terminal:

```bash
xcodebuild -project YATDL.xcodeproj -scheme YATDL -configuration Release
```

### CLI

```bash
make install
```

Compiles `cli/main.swift` as an arm64 Release binary and installs it to `/usr/local/bin/yatdl`.

To uninstall:

```bash
make uninstall
```

---

## Hotkey

The global hotkey is **Option+Space**, registered via the Carbon Event Manager (`RegisterEventHotKey`). This API predates the Input Monitoring permission system, so no special entitlement is required.

---

## Data Format

```json
{
  "lists": [
    {
      "id": "...",
      "name": "Personal",
      "items": [
        { "id": "...", "text": "Buy groceries", "isDone": false, "createdAt": "..." }
      ]
    }
  ],
  "selectedListID": "...",
  "displayMode": "dropFromMenubar"
}
```

Written atomically (`O_ATOMIC`) on every mutation.

---

## Project Structure

```
YATDL.xcodeproj/        Xcode project (arm64, macOS 14+)
YATDL/
  YATDLApp.swift        App entry point (@main, SwiftUI lifecycle)
  AppDelegate.swift     NSStatusItem, hotkey registration, panel lifecycle
  PanelController.swift NSPanel management, positioning, click-outside dismiss
  HotkeyManager.swift   Carbon RegisterEventHotKey wrapper
  TodoStore.swift       ObservableObject — in-memory state + persistence
  FileWatcher.swift     kqueue DispatchSource — watches data file for CLI writes
  TodoItem.swift        Model
  TodoList.swift        Model
  ContentView.swift     Root SwiftUI view
  TabBarView.swift      Tab bar + add-tab flow
  TodoListView.swift    List scroll view + item rows
  BottomToolbarView.swift  Display mode toggle, pin, delete list
  Info.plist            LSUIElement=YES, no NSMainStoryboardFile
  AppIcon.icns          App icon
cli/
  main.swift            Self-contained CLI (mirrors models, no shared framework)
Makefile                make cli / install / uninstall / clean
workflow.jsonl          Feature tracking (JSONL)
```

---

## Author

**Zac Leingang** — leingangzj@gmail.com
