project(
    'knotes',
    'vala', 'c',
    version: '0.1.0',
    meson_version: '>= 0.58.0',
    license: 'MIT'
)

gnome = import('gnome')

application_id = 'com.knotes.app'
project_name = 'knotes'
version = meson.project_version()

subdir('src')
subdir('data')

gnome.post_install(
    gtk_update_icon_cache: true
)
