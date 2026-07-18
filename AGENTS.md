# Repository Guidelines

## Project Structure & Module Organization

The Vala sources follow a lightweight hexagonal structure. `src/domain/` contains the `Note` and `Folder` models and must not depend on GTK or JSON. `src/application/` contains `NotebookService`, the query-oriented `NotebookCatalog`, and the abstract repository port in `application/ports/`. `src/infrastructure/json/` implements that port with JSON files, mappers, and directory monitoring.

`src/presentation/` contains GTK/Libadwaita code: the application shell, main window, tray integration, and sidebar components. `NoteListBox` coordinates the sidebar; `FolderTreeView`, `FolderDialogs`, `MoveDestinationDialog`, `NoteRow`, and `CompactNoteRow` own focused UI responsibilities. `src/bootstrap/` contains the entry point and `ApplicationFactory`, which wires infrastructure to application ports.

`data/` contains Blueprint templates, CSS, GResources, desktop metadata, and icons. `tests/` contains GLib tests for code that does not require a display. `po/` contains gettext files. Register new Vala sources in `src/meson.build`; register new translatable sources in `po/POTFILES`.

## Build, Test, and Development Commands

```bash
meson setup builddir
```

Configure a local build directory.

```bash
meson compile -C builddir
meson test -C builddir --print-errorlogs
```

Compile the application and run the automated tests.

```bash
./builddir/src/knotes
./builddir/src/knotes --tray
./builddir/src/knotes --start-minimized
```

Run normally, with tray support, or hidden in tray mode.

```bash
meson compile -C builddir knotes-pot
LANGUAGE=pl KNOTES_LOCALE_DIR="$PWD/builddir/po" ./builddir/src/knotes
```

Regenerate translation templates and test Polish translations from the build tree.

## Coding Style & Naming Conventions

Use 4-space indentation, namespace app code under `Knotes`, and follow the existing Vala style: `PascalCase` for classes and `snake_case` for methods, fields, locals, and signals. Keep declarative UI layout in Blueprint and behavior in Vala.

Dependencies point inward: presentation calls application services, application depends on domain and repository ports, and infrastructure implements those ports. Domain code must not import GTK, Adwaita, WebKit, JSON-GLib, or filesystem APIs. Keep serialization in mappers and construct concrete repositories only in `src/bootstrap/`. UI classes must request mutations through `NotebookService` rather than writing files or mutating `NotebookCatalog` directly.

Moving notes and folders is an application use case. Keep destination validation and cycle detection in `NotebookCatalog`/`NotebookService`; presentation code may pre-filter invalid drop targets but must still handle every `MoveResult`. Folder moves must reject the folder itself and all descendants. Preserve selected IDs, the search query, and expanded folder state when rebuilding the sidebar after a move.

Renaming a folder is also an application use case. Normalize and validate names in `NotebookService`, return a `RenameFolderResult`, and restore the previous name if persistence fails. Rebuild the derived sidebar tree after a successful rename so labels and destination paths stay consistent without changing the selected folder ID.

Translatable UI strings should go through the gettext helper in `src/i18n.vala`. When adding new files with user-visible strings, update `po/POTFILES`.

## Testing Guidelines

Treat `meson compile -C builddir` and `meson test -C builddir --print-errorlogs` as the minimum verification. Add GLib tests for domain and application behavior, especially folder hierarchy, search, and persistence-independent rules. For UI, tray, persistence, or translation work, also run the app manually with the relevant flags. Check note files under `~/.local/share/knotes/notes/` when changing storage behavior.

For move behavior, test note moves between folders and the root, folder moves between parents and the top level, no-op moves, missing destinations, cycle rejection, and persistence rollback. Manually verify both drag-and-drop and the keyboard-accessible move dialog (`Shift+F10` on a focused note or folder).

For rename behavior, test whitespace normalization, empty and unchanged names, missing folders, successful persistence, and rollback after a storage error. Manually verify that the selected folder, active search, and expanded tree state survive the rebuild.

## Commit & Pull Request Guidelines

Recent commits use short, imperative summaries such as `Move note creation out of NoteListBox` and `Ignore own note changes in file monitor`. Keep subject lines focused on one change and avoid bundling unrelated refactors.

Pull requests should describe the user-visible behavior change, list manual verification commands, and include screenshots or a short screen recording for visible UI changes. Mention tray-host or desktop-environment assumptions when changing tray behavior.

## Agent-Specific Instructions

Respect existing lifecycle boundaries: `startup()` owns one-time setup, `ensure_main_window()` owns lazy window construction, and restore/show behavior repairs minimized state before presenting. `ApplicationFactory` is the composition root; do not instantiate `JsonNotebookRepository` from presentation widgets or application services. Keep sidebar rendering in its focused presentation components and search/hierarchy rules in `NotebookCatalog`. Do not replace the pure GLib D-Bus tray implementation with external tray libraries unless the project explicitly chooses that dependency.
