project('notifications', 'vala', 'c')

i18n = import('i18n')

add_global_arguments(
    '-DGETTEXT_PACKAGE="' + meson.project_name() + '-indicator"',
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
    language:'c'
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
