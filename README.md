# Knotes

A simple note-taking application built with **Vala**, **GTK4**, **Libadwaita**, and **Blueprint**.

## Features

- Create, edit, and delete notes
- Organize notes in nested folders; rename folders and move notes or folders with drag-and-drop
- Search through notes by title or content
- Auto-save with debounced writes
- Add note-local images by dropping files into the editor or pasting images from the clipboard
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
- `libmarkdown` (Discount 3.x)

### Install dependencies (Ubuntu/Debian)

```bash
sudo apt install valac meson blueprint-compiler gettext libglib2.0-dev libgtk-4-dev libadwaita-1-dev libjson-glib-dev libgee-0.8-dev
```

Debian and Ubuntu currently package Discount 2.x. Install the Discount 3.x
development files from upstream before configuring Knotes.

### Install dependencies (Fedora)

```bash
sudo dnf install valac meson blueprint-compiler gettext glib2-devel gtk4-devel libadwaita-devel json-glib-devel libgee-devel discount-devel
```

### Install dependencies (openSUSE)

```bash
sudo zypper install valac meson blueprint-compiler gettext-tools glib2-devel gtk4-devel libadwaita-devel json-glib-devel libgee-devel libmarkdown-devel
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
│   ├── application/           # Application layer grouped by responsibility
│   │   ├── editing/           # Editing session and autosave coordination
│   │   ├── ports/             # Repository and scheduler boundaries
│   │   ├── results/           # Explicit application operation outcomes
│   │   ├── services/          # Note, folder, and asset use cases
│   │   └── workspace/         # Shared catalog and repository synchronization
│   ├── infrastructure/json/   # Note, folder, and asset JSON adapters
│   └── presentation/          # GTK shell, editor, sidebar, window, and tray components
├── data/
│   ├── meson.build            # Data build definition
│   ├── icons/
│   │   ├── meson.build        # Icon installation
│   │   ├── com.knotes.app.svg # Application icon (also used for tray)
│   │   ├── format-text-rich-symbolic-dark.svg  # Symbolic dark text format icon
│   │   └── format-text-rich-symbolic-light.svg # Symbolic light text format icon
│   ├── main_window.blp        # Main window Blueprint template compiled into GResource
│   ├── note_editor_pane.blp   # Note editor Blueprint template compiled into GResource
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
│   ├── notebook_application_test.vala # Domain and application tests
│   ├── json_notebook_repository_test.vala # JSON adapter tests
│   └── sidebar_state_test.vala # Display-free sidebar state tests
└── README.md
```

## Architecture

| Component | Responsibility |
|---|---|
| `Note`, `Folder` | Domain models without UI or persistence dependencies |
| `NotebookCatalog` | Search, sorting, folder hierarchy, and in-memory lookup |
| `NotebookWorkspace` | Owns the in-memory catalog and synchronizes external note changes |
| `NoteService`, `FolderService`, `NoteAssetService` | Focused application use cases |
| `NoteRepository`, `FolderRepository`, `NoteAssetRepository` | Segregated persistence ports |
| JSON repositories | Separate note, folder, and asset adapters sharing `JsonStorageLayout` |
| `SidebarSelectionModel` | Display-free owner of the logical note and folder selection |
| `SidebarCommandController` | Sidebar create, rename, delete, and move commands |
| `NoteListBox` | Composer of compact and expanded sidebar presentations |
| `SidebarTreeView`, row widgets, dialogs | Focused GTK sidebar rendering and interactions |
| `NoteEditorPane`, editor components | Editing, autosave, preview, and image-import presentation |
| `MainWindow` | Window shell, sidebar layout, header routing, and minimize-to-tray |
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

Notes are stored as individual JSON files under `~/.local/share/knotes/notes/`. Imported images are stored separately for each note:

```text
~/.local/share/knotes/notes/
├── <note-id>.json
└── <note-id>/
    └── assets/
        └── image.png
```

Dropped files and pasted clipboard images are inserted as relative Markdown references such as `![Diagram](assets/diagram.png)`. Supported formats are PNG, JPEG, GIF, WebP, SVG, BMP, and TIFF. Removing a reference stages the unused image for cleanup on the next application start, so undoing the edit before restarting can restore it.

The app uses a `GtkListBox` for the note list with real-time filtering. Edits are debounced at 500ms to avoid excessive disk writes.

## License

MIT
