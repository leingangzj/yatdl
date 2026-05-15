# YATDL — Yet Another To-Do List

A fast, native macOS menubar app for keeping your lists close without them getting in the way. No accounts, no sync services, no clutter — just your tasks, always a keystroke away.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Install

**Homebrew (recommended):**

```bash
brew install --cask leingangzj/yatdl/yatdl
```

Installs the app and the `yatdl` CLI tool in one step. Uninstall with `brew uninstall --cask yatdl`.

**Manual:**

Grab the latest **YATDL.dmg** from [Releases](https://github.com/leingangzj/yatdl/releases), open it, and drag YATDL into your Applications folder. Then open the app → right-click the bolt icon → Settings → **Install CLI Tool…** to get the `yatdl` terminal command.

---

## The App

### Lives in your menubar

YATDL runs entirely from the menu bar — no Dock icon, no Cmd+Tab clutter. Click the bolt icon or press **Option+Space** from anywhere to open it.

![Drop-down panel](screenshots/gui-dropdown.png)

It drops down right below the icon by default. Switch to **slide-in mode** and it glides in from the right edge of your screen, nudging your windows aside.

![Slide-in mode](screenshots/gui-slidein.png)

### Multiple lists, organized by sections

Keep up to three lists — Personal, Work, School, whatever fits. Each list can be broken into named sections so related tasks stay grouped together.

![Tabs and sections](screenshots/gui-tabs-sections.png)

Tabs sit across the top of the panel and resize automatically. You can move them to the left side or bottom if that works better for you.

### Emoji icons on everything

Every item can have an emoji icon. Hover a row and click the smiley face to pick one. Sections show a green ✓ and strikethrough automatically when every item in them is done.

![Work list with sections](screenshots/gui-worklist.png)

### Settings

Adjust font sizes, switch between light and dark mode, choose where tabs sit, and set the app to open at login. You can also export any list to CSV from here.

![Settings window](screenshots/gui-settings.png)

---

## Things worth knowing

- **Option+Space** opens and closes the panel from any app
- **Pin mode** keeps the panel open even when you click elsewhere
- **Hot-edge hover** — in slide-in mode, move your cursor to the right edge of the screen and the panel opens on its own
- **URL items** — paste any link as a to-do item and click it to open in your browser
- **Click-away saves** — editing a tab name, section, or item saves automatically when you click elsewhere
- **Drag to reorder** — items, sections, and tabs are all draggable
- **Deleting a list** shows a confirmation first
- Runs fully offline, no account required

---

## Terminal

If you spend time in the terminal, there's a `yatdl` CLI that reads and writes the same file as the app. Changes show up in the GUI instantly.

**To install it:** open the app, right-click the bolt icon → Settings → **Install CLI Tool…** — macOS will ask for your password once.

### Full-screen TUI (`yatdl -i`)

Arrow-key navigation, section management, emoji icons — everything from the GUI, in your terminal.

![TUI with sections](screenshots/tui-personal.png)

![TUI work list](screenshots/tui-work.png)

### Quick commands

```
yatdl                  show your current list
yatdl lists            show all lists
yatdl use <name>       switch lists
yatdl add <text>       add an item
yatdl done <num>       mark done
yatdl undo <num>       mark not done
yatdl rm <num>         remove an item
yatdl newtab <name>    create a list
yatdl rmtab <name>     delete a list
yatdl -i               open the TUI
yatdl help             show all commands
```

### TUI keys

**On an item:**

| Key | What it does |
|---|---|
| ↑ ↓ / j k | move up and down |
| Space | check / uncheck |
| `a` | add item |
| `e` | edit item |
| `i` | set emoji icon |
| `d` | delete item |
| `s` | add section |
| Tab / → | next list |
| Shift+Tab / ← | previous list |
| `n` | new list |
| q / Esc | quit |

**On a section header:**

| Key | What it does |
|---|---|
| `r` | rename section |
| `d` | delete section |
| `s` | add section |

---

## Build from source

Requires Swift command-line tools (`xcode-select --install`).

```bash
make install-app   # build and install the GUI to /Applications
make install       # build and install the yatdl CLI to /usr/local/bin
make dmg           # create a distributable .dmg
```

---

## License

MIT — see [LICENSE](LICENSE).

**Zac Leingang** — leingangzj@gmail.com — [github.com/leingangzj/yatdl](https://github.com/leingangzj/yatdl)
