# Knotes

A simple note-taking application built with **Vala**, **GTK4**, **Libadwaita**, and **Blueprint**.

## Features

- Create, edit, and delete notes
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
│   ├── main.vala              # Entry point, localization, flag parsing
│   ├── config.vala.in         # Build-time constants for localization
│   ├── application.vala       # Libadwaita Application subclass, tray lifecycle
│   ├── main_window.vala       # Main window template binding, editor wiring, minimize-to-tray
│   ├── i18n.vala              # gettext helper
│   ├── note.vala              # Note data model
│   ├── note_repository.vala   # File-based persistence layer
│   ├── note_list_box.vala     # Sidebar note list widget
│   └── tray_manager.vala      # StatusNotifierItem + D-BusMenu tray integration
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
└── README.md
```

## Architecture

| Component | Responsibility |
|---|---|
| `Note` | Data model — immutable properties, JSON serialization |
| `NoteRepository` | Persistence — filesystem read/write, directory monitoring |
| `NoteListBox` | Sidebar widget — search, list, row management |
| `MainWindow` | Libadwaita window template binding — split pane, editor, signal wiring, minimize-to-tray |
| `Application` | Entry point — Libadwaita application lifecycle, tray orchestration, start-minimized mode |
| `TrayManager` | **StatusNotifierItem** and **D-BusMenu** implementation (Wayland-ready) |

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
