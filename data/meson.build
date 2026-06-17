desktop_file = configure_file(
    input: meson.project_name() + '.desktop.in',
    output: meson.project_name() + '.desktop',
    configuration: configuration_data()
)

install_data(
    desktop_file,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

metainfo_file = configure_file(
    input: meson.project_name() + '.metainfo.xml.in',
    output: meson.project_name() + '.metainfo.xml',
    configuration: configuration_data()
)

install_data(
    metainfo_file,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

subdir('icons')
