i18n.merge_file(
    input: 'notifications.metainfo.xml.in',
    output: 'io.elementary.wingpanel.notifications.metainfo.xml',
    po_dir: meson.project_source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: get_option('datadir') / 'metainfo',
)

install_data('io.elementary.wingpanel.notifications.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)
