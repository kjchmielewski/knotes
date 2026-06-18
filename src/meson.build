sources = files(
    'main.vala',
    'application.vala',
    'main_window.vala',
    'note.vala',
    'note_repository.vala',
    'note_list_box.vala',
    'tray_manager.vala'
)

resources = gnome.compile_resources(
    'knotes-resources',
    '../data/knotes.gresource.xml',
    source_dir: '../data',
    c_name: 'knotes'
)

dependencies = [
    dependency('glib-2.0'),
    dependency('gio-2.0'),
    dependency('gtk4'),
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
    install: true
)
