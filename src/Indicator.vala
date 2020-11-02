/*-
 * Copyright 2015-2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Notifications.Indicator : Wingpanel.Indicator {
    private const string[] EXCEPTIONS = { "NetworkManager", "gnome-settings-daemon", "gnome-power-panel" };
    private const string CHILD_SCHEMA_ID = "io.elementary.notifications.applications";
    private const string CHILD_PATH = "/io/elementary/notifications/applications/%s/";
    private const string REMEMBER_KEY = "remember";

    private Gtk.Spinner? dynamic_icon = null;
    private Gtk.Grid? main_box = null;
    private Notifications.Session session;

    private GLib.ListStore notifications;
    private GLib.HashTable<string, GLib.DateTime> app_datetime;
    private Gee.HashMap<string, Settings> app_settings_cache;
    private GLib.Settings notify_settings;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.MESSAGES, visible: true);
    }

    construct {
        if (GLib.SettingsSchemaSource.get_default ().lookup ("io.elementary.notifications", true) != null) {
            debug ("Using io.elementary.notifications server");
            notify_settings = new GLib.Settings ("io.elementary.notifications");
        } else {
            debug ("Using notifications in gala");
            notify_settings = new GLib.Settings ("org.pantheon.desktop.gala.notifications");
        }

        app_datetime = new GLib.HashTable<string, GLib.DateTime> (str_hash, str_equal);
        app_settings_cache = new Gee.HashMap<string, Settings> ();
        notifications = new GLib.ListStore (typeof (Notifications.Notification));
    }

    public override Gtk.Widget get_display_widget () {
        if (dynamic_icon == null) {
            dynamic_icon = new Gtk.Spinner ();
            dynamic_icon.active = true;

            session = new Notifications.Session ();
            var previous_session = session.get_session_notifications ();
            foreach (unowned Notification notification in previous_session) {
                unowned GLib.DateTime? time = app_datetime[notification.desktop_id];
                if (time == null || time.compare (notification.timestamp) <= 0) {
                    app_datetime[notification.desktop_id] = notification.timestamp;
                }
            }

            notifications.splice (0, 0, (Object[]) previous_session);
            notifications.sort ((GLib.CompareDataFunc<GLib.Object>) sort_notification);

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("io/elementary/wingpanel/notifications/indicator.css");

            unowned Gtk.StyleContext dynamic_icon_style_context = dynamic_icon.get_style_context ();
            dynamic_icon_style_context.add_class ("notification-icon");
            dynamic_icon_style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var monitor = NotificationMonitor.get_instance ();
            monitor.notification_received.connect (on_notification_received);
            monitor.notification_closed.connect (on_notification_closed);

            dynamic_icon.button_press_event.connect ((e) => {
                if (e.button == Gdk.BUTTON_MIDDLE) {
                    notify_settings.set_boolean ("do-not-disturb", !notify_settings.get_boolean ("do-not-disturb"));
                    return Gdk.EVENT_STOP;
                }

                return Gdk.EVENT_PROPAGATE;
            });

            notify_settings.changed["do-not-disturb"].connect (() => {
                set_display_icon_name ();
            });

            notifications.items_changed.connect ((position, removed, added) => {
                set_display_icon_name ();
            });

            set_display_icon_name ();
        }

        return dynamic_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (main_box == null) {
            var nlist = new NotificationsList (notifications);

            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scrolled.max_content_height = 500;
            scrolled.propagate_natural_height = true;
            scrolled.add (nlist);

            var not_disturb_switch = new Wingpanel.Widgets.Switch (_("Do Not Disturb"));
            not_disturb_switch.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

            var clear_all_btn = new Gtk.ModelButton ();
            clear_all_btn.text = _("Clear All Notifications");

            var settings_btn = new Gtk.ModelButton ();
            settings_btn.text = _("Notifications Settings…");

            main_box = new Gtk.Grid ();
            main_box.orientation = Gtk.Orientation.VERTICAL;
            main_box.width_request = 300;
            main_box.add (not_disturb_switch);
            main_box.add (new Wingpanel.Widgets.Separator ());
            main_box.add (scrolled);
            main_box.add (new Wingpanel.Widgets.Separator ());
            main_box.add (clear_all_btn);
            main_box.add (settings_btn);
            main_box.show_all ();

            notify_settings.bind ("do-not-disturb", not_disturb_switch, "active", GLib.SettingsBindFlags.DEFAULT);

            nlist.clear_app.connect ((app_id) => {
                nlist.get_children ().foreach ((child) => {
                    if (child is NotificationEntry) {
                        unowned NotificationEntry entry = (NotificationEntry) child;
                        if (entry.notification.desktop_id == app_id) {
                            entry.dismiss ();
                        }
                    }
                });
            });

            nlist.remove_notification.connect ((notification) => {
                uint position;
                if (notifications.find (notification, out position)) {
                    session.remove_notification (notification);
                    notifications.remove (position);
                } else {
                    warning ("Notification not found!");
                }
            });

            nlist.close_popover.connect (() => close ());

            clear_all_btn.clicked.connect (() => {
                session.clear ();
                nlist.get_children ().foreach ((child) => {
                    if (child is NotificationEntry) {
                        ((NotificationEntry) child).dismiss ();
                    }
                });
            });

            notifications.items_changed.connect ((position, removed, added) => {
                clear_all_btn.sensitive = notifications.get_n_items () > 0;
            });

            settings_btn.clicked.connect (show_settings);
        }

        return main_box;
    }

    public override void opened () {
    }

    public override void closed () {

    }

    private void on_notification_received (DBusMessage message, uint32 id) {
        var notification = new Notification.from_message (message, id);
        if (notification.is_transient || notification.app_name in EXCEPTIONS) {
            return;
        }

        string app_id = notification.desktop_id.replace (Notification.DESKTOP_ID_EXT, "");

        Settings? app_settings = app_settings_cache.get (app_id);

        var schema = SettingsSchemaSource.get_default ().lookup (CHILD_SCHEMA_ID, true);
        if (schema != null && app_settings == null && app_id != "") {
            app_settings = new Settings.full (schema, null, CHILD_PATH.printf (app_id));
            app_settings_cache.set (app_id, app_settings);
        }

        if (app_settings == null || app_settings.get_boolean (REMEMBER_KEY)) {
            unowned GLib.DateTime? time = app_datetime[notification.desktop_id];
            if (time == null || time.compare (notification.timestamp) <= 0) {
                app_datetime[notification.desktop_id] = notification.timestamp;
            }

            notifications.insert_sorted (notification, (GLib.CompareDataFunc<GLib.Object>) sort_notification);
            session.add_notification (notification);
        }
    }

    [CCode (instance_pos = -1)]
    private int sort_notification (Notification a, Notification b) {
        if (a.desktop_id == b.desktop_id) {
            return Notification.compare (a, b);
        } else {
            unowned GLib.DateTime? time_a = app_datetime[a.desktop_id];
            unowned GLib.DateTime? time_b = app_datetime[b.desktop_id];
            if (time_a != null && time_b != null) {
                return time_a.compare (time_b);
            } else if (time_a != null) {
                return -1;
            } else if (time_b != null) {
                return 1;
            } else {
                return 0;
            }
        }
    }

    private void on_notification_closed (uint32 id) {
        for (int i = 0; i < notifications.get_n_items (); i++) {
            var notification = (Notification) notifications.get_item (i);
            if (notification.id == id) {
                notification.close ();
                return;
            }
        }
    }

    private void set_display_icon_name () {
        unowned Gtk.StyleContext dynamic_icon_style_context = dynamic_icon.get_style_context ();
        if (notify_settings.get_boolean ("do-not-disturb")) {
            dynamic_icon_style_context.add_class ("disabled");
        } else if (notifications.get_n_items () > 0) {
            dynamic_icon_style_context.remove_class ("disabled");
            dynamic_icon_style_context.add_class ("new");
        } else {
            dynamic_icon_style_context.remove_class ("disabled");
            dynamic_icon_style_context.remove_class ("new");
        }
    }

    private void show_settings () {
        close ();

        try {
            AppInfo.launch_default_for_uri ("settings://notifications", null);
        } catch (Error e) {
            warning ("Failed to open notifications settings: %s", e.message);
        }
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating Notifications Indicator");

    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION) {
        return null;
    }

    var indicator = new Notifications.Indicator ();
    return indicator;
}
