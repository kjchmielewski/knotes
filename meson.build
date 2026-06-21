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

gnome.post_install(
    gtk_update_icon_cache: true
)
