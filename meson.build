project(
    'knotes',
    'vala', 'c',
    version: '0.1.0',
    meson_version: '>= 0.58.0',
    license: 'MIT'
)

gnome = import('gnome')
i18n = import('i18n')

application_id = 'com.knotes.app'
project_name = 'knotes'
gettext_package = project_name
version = meson.project_version()

config_data = configuration_data()
config_data.set_quoted('GETTEXT_PACKAGE', gettext_package)
config_data.set_quoted('LOCALE_DIR', join_paths(get_option('prefix'), get_option('localedir')))
config_file = configure_file(
    input: 'src/config.vala.in',
    output: 'config.vala',
    configuration: config_data
)

subdir('src')
subdir('data')
subdir('po')

notebook_application_test = executable(
    'notebook-application-test',
    files(
        'tests/notebook_application_test.vala',
        'src/domain/note.vala',
        'src/domain/folder.vala',
        'src/application/notebook_catalog.vala',
        'src/application/notebook_workspace.vala',
        'src/application/asset_import_result.vala',
        'src/application/duplicate_note_result.vala',
        'src/application/move_result.vala',
        'src/application/rename_folder_result.vala',
        'src/application/ports/note_repository.vala',
        'src/application/ports/folder_repository.vala',
        'src/application/ports/note_asset_repository.vala',
        'src/application/note_service.vala',
        'src/application/folder_service.vala',
        'src/application/note_asset_service.vala',
        'src/presentation/editor/autosave_coordinator.vala'
    ),
    dependencies: [
        dependency('glib-2.0'),
        dependency('gio-2.0'),
        dependency('gee-0.8')
    ]
)

test('notebook-application', notebook_application_test)

json_notebook_repository_test = executable(
    'json-notebook-repository-test',
    files(
        'tests/json_notebook_repository_test.vala',
        'src/domain/note.vala',
        'src/domain/folder.vala',
        'src/application/asset_import_result.vala',
        'src/application/ports/note_repository.vala',
        'src/application/ports/folder_repository.vala',
        'src/application/ports/note_asset_repository.vala',
        'src/infrastructure/json/note_json_mapper.vala',
        'src/infrastructure/json/folder_json_mapper.vala',
        'src/infrastructure/json/json_storage_layout.vala',
        'src/infrastructure/json/json_note_asset_storage.vala',
        'src/infrastructure/json/json_note_repository.vala',
        'src/infrastructure/json/json_folder_repository.vala',
        'src/infrastructure/json/json_note_asset_repository.vala'
    ),
    dependencies: [
        dependency('glib-2.0'),
        dependency('gio-2.0'),
        dependency('json-glib-1.0'),
        dependency('gee-0.8')
    ]
)

test('json-notebook-repository', json_notebook_repository_test)

sidebar_state_test = executable(
    'sidebar-state-test',
    files(
        'tests/sidebar_state_test.vala',
        'src/domain/note.vala',
        'src/domain/folder.vala',
        'src/application/notebook_catalog.vala',
        'src/presentation/sidebar/sidebar_selection_model.vala',
        'src/presentation/sidebar/sidebar_drag_item.vala'
    ),
    dependencies: [
        dependency('glib-2.0'),
        dependency('gee-0.8')
    ]
)

test('sidebar-state', sidebar_state_test)

markdown_rendering_test = executable(
    'markdown-rendering-test',
    files('tests/markdown_rendering_test.vala'),
    libmarkdown_vapi,
    dependencies: [
        dependency('glib-2.0'),
        markdown_dependency
    ]
)

test('markdown-rendering', markdown_rendering_test)

gnome.post_install(
    gtk_update_icon_cache: true
)
