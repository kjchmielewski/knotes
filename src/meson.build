sources = files(
    'main.vala',
    'application.vala',
    'main_window.vala',
    'note.vala',
    'note_repository.vala',
    'note_list_box.vala',
    'tray_manager.vala'
)

blueprint_compiler = find_program('blueprint-compiler')

main_window_ui = custom_target(
    'main-window-ui',
    input: '../data/main_window.blp',
    output: 'main_window.ui',
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
    dependencies: [main_window_ui, note_list_box_ui, note_row_ui],
    c_name: 'knotes'
)

dependencies = [
    dependency('glib-2.0'),
    dependency('gio-2.0'),
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('cairo'),
    dependency('gdk-pixbuf-2.0'),
    dependency('json-glib-1.0'),
    dependency('gee-0.8')
]

executable(
    meson.project_name(),
    sources,
    resources,
    dependencies: dependencies,
    vala_args: ['--gresourcesdir=' + meson.current_build_dir()],
    install: true
)
