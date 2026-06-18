install_data(
    meson.project_name() + '.desktop.in',
    rename: application_id + '.desktop',
    install_dir: join_paths(get_option('datadir'), 'applications')
)

install_data(
    meson.project_name() + '.metainfo.xml.in',
    rename: application_id + '.metainfo.xml',
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

subdir('icons')
