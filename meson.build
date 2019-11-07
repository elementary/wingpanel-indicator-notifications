project(
    'notifications',
    'vala', 'c',
    version: '2.1.2'
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

asresources = gnome.compile_resources(
    'as-resources', 'data/io.elementary.wingpanel.notifications.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

wingpanel_dep = dependency('wingpanel-2.0')
wingpanel_indicatorsdir = wingpanel_dep.get_pkgconfig_variable('indicatorsdir', define_variable: ['libdir', libdir])

shared_module(
    meson.project_name(),
    'src/Indicator.vala',
    'src/Widgets/NotificationsList.vala',
    'src/Widgets/NotificationEntry.vala',
    'src/Widgets/AppEntry.vala',
    'src/Widgets/SeparatorEntry.vala',
    'src/Services/NotificationsMonitor.vala',
    'src/Services/Notification.vala',
    'src/Services/NotifySettings.vala',
    'src/Services/Session.vala',
    'src/Services/Interfaces.vala',
    asresources,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite'),
        dependency('gtk+-3.0'),
        dependency('libwnck-3.0'),
        wingpanel_dep
    ],
    install: true,
    install_dir : wingpanel_indicatorsdir,
)

subdir('data')
subdir('po')
