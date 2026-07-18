sources = files(
    'bootstrap/main.vala',
    'bootstrap/application_factory.vala',
    'bootstrap/application_services.vala',
    'presentation/shell/application.vala',
    'i18n.vala',
    'presentation/window/main_window.vala',
    'domain/note.vala',
    'domain/folder.vala',
    'application/notebook_catalog.vala',
    'application/notebook_workspace.vala',
    'application/asset_import_result.vala',
    'application/move_result.vala',
    'application/rename_folder_result.vala',
    'application/ports/note_repository.vala',
    'application/ports/folder_repository.vala',
    'application/ports/note_asset_repository.vala',
    'application/note_service.vala',
    'application/folder_service.vala',
    'application/note_asset_service.vala',
    'infrastructure/json/note_json_mapper.vala',
    'infrastructure/json/folder_json_mapper.vala',
    'infrastructure/json/json_storage_layout.vala',
    'infrastructure/json/json_note_asset_storage.vala',
    'infrastructure/json/json_note_repository.vala',
    'infrastructure/json/json_folder_repository.vala',
    'infrastructure/json/json_note_asset_repository.vala',
    'presentation/editor/autosave_coordinator.vala',
    'presentation/editor/markdown_editor_view.vala',
    'presentation/editor/markdown_preview_pane.vala',
    'presentation/editor/note_asset_import_controller.vala',
    'presentation/editor/note_editor_pane.vala',
    'presentation/sidebar/sidebar_selection_model.vala',
    'presentation/sidebar/sidebar_drag_item.vala',
    'presentation/sidebar/sidebar_item_interactions.vala',
    'presentation/sidebar/folder_button_renderer.vala',
    'presentation/sidebar/sidebar_command_controller.vala',
    'presentation/sidebar/note_row.vala',
    'presentation/sidebar/compact_note_row.vala',
    'presentation/sidebar/sidebar_tree_view.vala',
    'presentation/sidebar/folder_dialogs.vala',
    'presentation/sidebar/move_destination_dialog.vala',
    'presentation/sidebar/note_list_box.vala',
    'presentation/tray/tray_manager.vala'
)

sources += config_file

cc = meson.get_compiler('c')
cmark_dependency = cc.find_library('cmark', required: true)

blueprint_compiler = find_program('blueprint-compiler')

main_window_ui = custom_target(
    'main-window-ui',
    input: '../data/main_window.blp',
    output: 'main_window.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@']
)

note_editor_pane_ui = custom_target(
    'note-editor-pane-ui',
    input: '../data/note_editor_pane.blp',
    output: 'note_editor_pane.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@']
)

note_list_box_ui = custom_target(
    'note-list-box-ui',
    input: '../data/note_list_box.blp',
    output: 'note_list_box.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@']
)

note_row_ui = custom_target(
    'note-row-ui',
    input: '../data/note_row.blp',
    output: 'note_row.ui',
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@']
)

resources = gnome.compile_resources(
    'knotes-resources',
    '../data/knotes.gresource.xml',
    source_dir: ['../data', meson.current_build_dir()],
    dependencies: [main_window_ui, note_editor_pane_ui, note_list_box_ui, note_row_ui],
    c_name: 'knotes'
)

dependencies = [
    dependency('glib-2.0'),
    dependency('gio-2.0'),
    dependency('gtk4', version: '>= 4.12'),
    dependency('gtksourceview-5'),
    dependency('webkitgtk-6.0'),
    dependency('libadwaita-1', version: '>= 1.5'),
    dependency('cairo'),
    dependency('gdk-pixbuf-2.0'),
    dependency('json-glib-1.0'),
    dependency('gee-0.8'),
    cmark_dependency
]

executable(
    meson.project_name(),
    sources,
    resources,
    dependencies: dependencies,
    c_args: ['-DGETTEXT_PACKAGE="@0@"'.format(gettext_package)],
    vala_args: ['--gresourcesdir=' + meson.current_build_dir()],
    install: true
)
