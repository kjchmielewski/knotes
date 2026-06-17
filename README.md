# Knotes

A simple note-taking application built with **Vala** and **GTK4**.

## Features

- Create, edit, and delete notes
- Search through notes by title or content
- Auto-save with debounced writes
- Notes stored locally as JSON files (`~/.local/share/knotes/notes/`)
- Real-time file monitoring — changes from external editors are reflected instantly
- Optional system tray icon (pass `--tray`) — uses the modern StatusNotifierItem D-Bus protocol, compatible with Wayland, GNOME, KDE, and other DEs

## Dependencies

- `valac` (Vala compiler)
- `meson` (build system)
- `glib-2.0`
- `gio-2.0`
- `gtk4`
- `json-glib-1.0`
- `gee-0.8`

### Install dependencies (Ubuntu/Debian)

```bash
sudo apt install valac meson libglib2.0-dev libgtk-4-dev libjson-glib-dev libgee-0.8-dev
```

### Install dependencies (Fedora)

```bash
sudo dnf install valac meson glib2-devel gtk4-devel json-glib-devel libgee-devel
```

### Install dependencies (openSUSE)

```bash
sudo zypper install valac meson glib2-devel gtk4-devel json-glib-devel libgee-devel
```

## Build and Run

```bash
meson setup builddir
meson compile -C builddir
./builddir/knotes              # Without tray icon
./builddir/knotes --tray       # With tray icon (minimizes to tray on close)
```

### Install system-wide

```bash
meson setup builddir
meson install -C builddir
```

## Project Structure

```
knotes/
├── meson.build                # Root build definition
├── src/
│   ├── meson.build            # Source build definition
│   ├── main.vala              # Entry point (--tray flag parsing)
│   ├── application.vala       # GTK Application subclass, tray lifecycle
│   ├── main_window.vala       # Main window layout, minimize-to-tray
│   ├── note.vala              # Note data model
│   ├── note_repository.vala   # File-based persistence layer
│   ├── note_list_box.vala     # Sidebar note list widget
│   └── tray_manager.vala      # StatusNotifierItem D-Bus tray icon
├── data/
│   ├── meson.build            # Data build definition
│   ├── icons/
│   │   ├── meson.build        # Icon installation
│   │   └── com.knotes.app.svg # Application icon (also used for tray)
│   ├── knotes.desktop.in      # Desktop entry
│   └── knotes.metainfo.xml.in # AppStream metadata
└── README.md
```

## Architecture

| Component | Responsibility |
|---|---|
| `Note` | Data model — immutable properties, JSON serialization |
| `NoteRepository` | Persistence — filesystem read/write, directory monitoring |
| `NoteListBox` | Sidebar widget — search, list, row management |
| `MainWindow` | Layout — split pane, editor, signal wiring, minimize-to-tray |
| `Application` | Entry point — GTK application lifecycle, tray orchestration |
| `TrayManager` | **StatusNotifierItem** D-Bus implementation (Wayland-ready) |

## Tray Icon

Enable with `--tray`:

```bash
./builddir/knotes --tray
```

The tray icon:
- Uses the **StatusNotifierItem** D-Bus protocol – the modern system tray standard adopted by KDE, GNOME (via AppIndicator extension), and others
- Works on both **X11 and Wayland**
- Has zero additional runtime dependencies – pure GLib D-Bus
- **Left-click** toggles the main window visibility
- **Right-click** also toggles the window
- Closing the window minimizes to tray instead of quitting
- Use the `Quit` action from the tray to fully exit

No external tray libraries (`libappindicator`, etc.) are needed.

Notes are stored as individual JSON files under `~/.local/share/knotes/notes/`. The app uses a `GtkListBox` for the note list with real-time filtering. Edits are debounced at 500ms to avoid excessive disk writes.

## License

MIT
