sources = files(
    'main.vala',
    'application.vala',
    'main_window.vala',
    'note.vala',
    'note_repository.vala',
    'note_list_box.vala',
    'tray_manager.vala'
)

dependencies = [
    dependency('glib-2.0'),
    dependency('gio-2.0'),
    dependency('gtk4'),
    dependency('json-glib-1.0'),
    dependency('gee-0.8')
]

executable(
    meson.project_name(),
    sources,
    dependencies: dependencies,
    install: true
)
