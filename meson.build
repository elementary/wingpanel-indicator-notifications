project('notifications', 'vala', 'c')

i18n = import('i18n')

add_global_arguments(
    '-DGETTEXT_PACKAGE="' + meson.project_name() + '-indicator"',
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
    language:'c'
)

configuration_data = configuration_data()
configuration_data.set('DATADIR', get_option('libdir') + '/wingpanel')
configuration_data.set('PKGDATADIR', get_option('libdir') + '/wingpanel')
configuration_data.set('GETTEXT_PACKAGE', meson.project_name() + '-indicator')

config_file = configure_file(
    input: 'config.vala.cmake',
    output: 'config.vala',
    configuration: configuration_data
)

shared_module(
    meson.project_name(),
    'src/Indicator.vala',
    'src/Utils.vala',
    'src/Widgets/NotificationsList.vala',
    'src/Widgets/NotificationEntry.vala',
    'src/Widgets/AppEntry.vala',
    'src/Widgets/SeparatorEntry.vala',
    'src/Services/NotificationsMonitor.vala',
    'src/Services/Notification.vala',
    'src/Services/NotifySettings.vala',
    'src/Services/Session.vala',
    'src/Services/Interfaces.vala',
    config_file,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite'),
        dependency('gtk+-3.0'),
        dependency('libwnck-3.0'),
        dependency('wingpanel-2.0')
    ],
    install: true,
    install_dir : get_option('libdir') + '/wingpanel'
)

subdir('po')
