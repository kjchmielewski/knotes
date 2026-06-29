# Repository Guidelines

## Project Structure & Module Organization

`src/` contains the Vala application code. Key modules are `application.vala` for the Libadwaita application lifecycle, `main_window.vala` for the main UI wiring, `note_repository.vala` for JSON-file persistence, `note_list_box.vala` for the sidebar, and `tray_manager.vala` for StatusNotifierItem/D-BusMenu tray integration.

`data/` contains UI and desktop assets: Blueprint templates (`*.blp`), `style.css`, the GResource manifest, desktop metadata, and the application icon. `po/` contains gettext translation files, including `pl.po`. Build definitions live in `meson.build`, `src/meson.build`, `data/meson.build`, and `po/meson.build`.

## Build, Test, and Development Commands

```bash
meson setup builddir
```

Configure a local build directory.

```bash
meson compile -C builddir
```

Compile Vala sources, Blueprint templates, resources, and translations.

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

Use 4-space indentation, namespace all app code under `Knotes`, and follow the existing Vala style: `PascalCase` for classes, `snake_case` for methods, fields, locals, and signal names. Keep UI layout in Blueprint files and behavior in Vala. Prefer small private helper methods for lifecycle steps, especially around window creation, tray restore, and persistence.

Translatable UI strings should go through the gettext helper in `src/i18n.vala`. When adding new files with user-visible strings, update `po/POTFILES`.

## Testing Guidelines

There is no dedicated automated test suite yet. Treat `meson compile -C builddir` as the minimum verification for every change. For UI, tray, persistence, or translation work, also run the app manually with the relevant flags. Check note files under `~/.local/share/knotes/notes/` when changing storage behavior.

## Commit & Pull Request Guidelines

Recent commits use short, imperative summaries such as `Move note creation out of NoteListBox` and `Ignore own note changes in file monitor`. Keep subject lines focused on one change and avoid bundling unrelated refactors.

Pull requests should describe the user-visible behavior change, list manual verification commands, and include screenshots or a short screen recording for visible UI changes. Mention tray-host or desktop-environment assumptions when changing tray behavior.

## Agent-Specific Instructions

Respect existing lifecycle boundaries: `startup()` owns one-time setup, `ensure_main_window()` owns lazy window construction, and restore/show behavior should repair minimized state before presenting. Do not replace the current pure GLib D-Bus tray implementation with external tray libraries unless the project explicitly chooses that dependency.
