# Knotes

A simple note-taking application built with **Vala**, **GTK4**, **Libadwaita**, and **Blueprint**.

## Features

- Create, edit, and delete notes
- Organize notes in nested folders; rename folders and move notes or folders with drag-and-drop
- Search through notes by title or content
- Auto-save with debounced writes
- Notes stored locally as JSON files (`~/.local/share/knotes/notes/`)
- Real-time file monitoring — changes from external editors are reflected instantly
- Optional system tray icon (pass `--tray`) — uses the modern StatusNotifierItem D-Bus protocol, compatible with X11/Wayland tray hosts such as KDE Plasma and Xfce
- Start directly minimized to tray with `--start-minimized`
- Tray context menu with `Quit` action

## Dependencies

- `valac` (Vala compiler)
- `meson` (build system)
- `glib-2.0`
- `gio-2.0`
- `gtk4`
- `libadwaita-1`
- `blueprint-compiler`
- `gettext`
- `json-glib-1.0`
- `gee-0.8`

### Install dependencies (Ubuntu/Debian)

```bash
sudo apt install valac meson blueprint-compiler gettext libglib2.0-dev libgtk-4-dev libadwaita-1-dev libjson-glib-dev libgee-0.8-dev
```

### Install dependencies (Fedora)

```bash
sudo dnf install valac meson blueprint-compiler gettext glib2-devel gtk4-devel libadwaita-devel json-glib-devel libgee-devel
```

### Install dependencies (openSUSE)

```bash
sudo zypper install valac meson blueprint-compiler gettext-tools glib2-devel gtk4-devel libadwaita-devel json-glib-devel libgee-devel
```

## Build and Run

```bash
meson setup builddir
meson compile -C builddir
./builddir/src/knotes                         # Without tray icon
./builddir/src/knotes --tray                  # With tray icon (minimizes to tray on close)
./builddir/src/knotes --start-minimized       # Start hidden, tray icon only
```

`--start-minimized` automatically enables tray mode, so `--tray` is not required with it.

### Translations

Polish UI translations are installed through gettext. After installation, they are loaded automatically for a Polish locale.

For testing translations directly from the build directory without installing:

```bash
LANGUAGE=pl KNOTES_LOCALE_DIR="$PWD/builddir/po" ./builddir/src/knotes
```

Regenerate the translation template after changing translatable strings:

```bash
meson compile -C builddir knotes-pot
```

### Install

For a per-user install:

```bash
meson setup builddir --prefix=$HOME/.local
meson install -C builddir
```

Installed files include:

- `~/.local/bin/knotes`
- `~/.local/share/applications/com.knotes.app.desktop`
- `~/.local/share/icons/hicolor/scalable/apps/com.knotes.app.svg`
- `~/.local/share/metainfo/com.knotes.app.metainfo.xml`

The build runs `gtk-update-icon-cache` after installation so desktop environments can resolve the application icon by name.

## Project Structure

```
knotes/
├── AGENTS.md
├── meson.build                # Root build definition
├── src/
│   ├── meson.build            # Source build definition
│   ├── config.vala.in         # Build-time constants for localization
│   ├── i18n.vala              # gettext helper
│   ├── bootstrap/             # Entry point and dependency composition
│   ├── domain/                # Note and Folder models
│   ├── application/           # Use cases, catalog queries, repository port
│   ├── infrastructure/json/   # JSON persistence, mappers, file monitoring
│   └── presentation/          # GTK window, shell, sidebar, and tray components
├── data/
│   ├── meson.build            # Data build definition
│   ├── icons/
│   │   ├── meson.build        # Icon installation
│   │   ├── com.knotes.app.svg # Application icon (also used for tray)
│   │   ├── format-text-rich-symbolic-dark.svg  # Symbolic dark text format icon
│   │   └── format-text-rich-symbolic-light.svg # Symbolic light text format icon
│   ├── main_window.blp        # Main window Blueprint template compiled into GResource
│   ├── note_list_box.blp      # Note list Blueprint template compiled into GResource
│   ├── note_row.blp           # Note row Blueprint template compiled into GResource
│   ├── knotes.gresource.xml   # GResource manifest for generated UI, CSS, and icons
│   ├── style.css              # Application CSS
│   ├── knotes.desktop.in      # Desktop entry
│   └── knotes.metainfo.xml.in # AppStream metadata
├── po/
│   ├── knotes.pot             # Template for translatable strings
│   ├── meson.build            # Meson build configuration for translations
│   ├── LINGUAS                # Enabled translations
│   ├── POTFILES               # Sources scanned for translatable strings
│   ├── POTFILES.skip          # Sources to skip during translation scanning
│   └── pl.po                  # Polish translation
├── tests/
│   └── notebook_application_test.vala # Domain and application tests
└── README.md
```

## Architecture

| Component | Responsibility |
|---|---|
| `Note`, `Folder` | Domain models without UI or persistence dependencies |
| `NotebookCatalog` | Search, sorting, folder hierarchy, and in-memory lookup |
| `NotebookService` | Note and folder use cases; coordinates the repository port |
| `NotebookRepository` | Application port for persistence and external-change events |
| `JsonNotebookRepository` | JSON filesystem persistence and directory monitoring |
| `NoteListBox` | Sidebar coordinator for compact and expanded presentations |
| `FolderTreeView`, row widgets, dialogs | Focused GTK sidebar components |
| `MainWindow` | Libadwaita window template binding — split pane, editor, signal wiring, minimize-to-tray |
| `Application` | Libadwaita lifecycle, tray orchestration, and start-minimized mode |
| `ApplicationFactory` | Composition root connecting the JSON adapter to application services |
| `TrayManager` | **StatusNotifierItem** and **D-BusMenu** implementation (Wayland-ready) |

Notes and folders can be dragged onto another folder or onto **All notes** to move them to the top level. To choose a destination without drag-and-drop, right-click an item, or focus it and press `Shift+F10`. Invalid folder destinations (the folder itself and its descendants) are omitted.

Select a folder and use the edit button in the header bar to rename it. Leading and trailing whitespace is removed, and an empty name is rejected.

## Tray Icon

Enable with `--tray`:

```bash
./builddir/src/knotes --tray
```

Start hidden with only the tray icon visible:

```bash
./builddir/src/knotes --start-minimized
```

The tray icon:

- Uses the **StatusNotifierItem** D-Bus protocol – the modern system tray standard adopted by KDE, Xfce, GNOME (via AppIndicator extension), and others
- Uses **D-BusMenu** for the tray context menu
- Works on both **X11 and Wayland**, depending on tray host support
- Has zero additional runtime dependencies – pure GLib D-Bus
- **Left-click** toggles the main window visibility
- **Right-click** opens a context menu with `Quit`
- Closing the window minimizes to tray instead of quitting when tray mode is enabled
- `Quit` exits the application fully, equivalent to `Ctrl+Q`

The tray icon is exposed primarily by icon name (`com.knotes.app`) and installed into the `hicolor` icon theme. A standards-compliant empty `IconPixmap` is provided so tray hosts prefer the themed icon. No external tray libraries (`libappindicator`, etc.) are needed.

Notes are stored as individual JSON files under `~/.local/share/knotes/notes/`. The app uses a `GtkListBox` for the note list with real-time filtering. Edits are debounced at 500ms to avoid excessive disk writes.

## License

MIT
