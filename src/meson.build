sources = files(
    'main.vala',
    'application.vala',
    'i18n.vala',
    'main_window.vala',
    'note.vala',
    'folder.vala',
    'note_repository.vala',
    'note_list_box.vala',
    'tray_manager.vala'
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
