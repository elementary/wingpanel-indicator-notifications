project(
    'notifications',
    'vala', 'c',
    version: '7.1.1'
)

gettext_name = meson.project_name() + '-indicator'
gnome = import('gnome')
i18n = import('i18n')

prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))

add_global_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(gettext_name),
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
    language:'c'
)
add_project_arguments('-DG_LOG_DOMAIN="io.elementary.wingpanel.notifications"', language:'c')

gresource = gnome.compile_resources(
    'gresource',
    'data' / 'gresource.xml',
    source_dir: 'data'
)

wingpanel_dep = dependency('wingpanel')
wingpanel_indicatorsdir = wingpanel_dep.get_pkgconfig_variable('indicatorsdir', define_variable: ['libdir', libdir])

config_data = configuration_data()
config_data.set('GETTEXT_PACKAGE', meson.project_name() + '-indicator')
config_data.set('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
config_vala = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

shared_module(
    meson.project_name(),
    'src/Indicator.vala',
    'src/Widgets/MaskedImage.vala',
    'src/Widgets/NotificationsList.vala',
    'src/Widgets/NotificationEntry.vala',
    'src/Widgets/AppEntry.vala',
    'src/Services/NotificationsMonitor.vala',
    'src/Services/Notification.vala',
    'src/Services/Session.vala',
    gresource,
    config_vala,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite', version: '>=6.0.0'),
        dependency('gtk+-3.0'),
        dependency('libhandy-1'),
        wingpanel_dep
    ],
    install: true,
    install_dir : wingpanel_indicatorsdir,
)

gnome.post_install (glib_compile_schemas: true)

subdir('data')
subdir('po')
