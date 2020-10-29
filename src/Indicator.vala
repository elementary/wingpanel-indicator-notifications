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
    private Gtk.ModelButton clear_all_btn;
    private Wingpanel.Widgets.Switch not_disturb_switch;

    private NotificationsList nlist;

    private Gee.HashMap<string, Settings> app_settings_cache;

    public static GLib.Settings notify_settings;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.MESSAGES);

        visible = true;
    }

    construct {
        app_settings_cache = new Gee.HashMap<string, Settings> ();
    }

    static construct {
        if (GLib.SettingsSchemaSource.get_default ().lookup ("io.elementary.notifications", true) != null) {
            debug ("Using io.elementary.notifications server");
            notify_settings = new GLib.Settings ("io.elementary.notifications");
        } else {
            debug ("Using notifications in gala");
            notify_settings = new GLib.Settings ("org.pantheon.desktop.gala.notifications");
        }
    }

    public override Gtk.Widget get_display_widget () {
        if (dynamic_icon == null) {
            dynamic_icon = new Gtk.Spinner ();
            dynamic_icon.active = true;

            nlist = new NotificationsList ();

            var previous_session = Session.get_instance ().get_session_notifications ();
            previous_session.foreach ((notification) => {
                nlist.add_entry (notification);
            });

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

            nlist.add.connect (set_display_icon_name);
            nlist.remove.connect (set_display_icon_name);

            set_display_icon_name ();
        }

        return dynamic_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (main_box == null) {
            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scrolled.max_content_height = 500;
            scrolled.propagate_natural_height = true;
            scrolled.add (nlist);

            not_disturb_switch = new Wingpanel.Widgets.Switch (_("Do Not Disturb"));
            not_disturb_switch.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

            clear_all_btn = new Gtk.ModelButton ();
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

            nlist.close_popover.connect (() => close ());
            nlist.add.connect (update_clear_all_sensitivity);
            nlist.remove.connect (update_clear_all_sensitivity);

            clear_all_btn.clicked.connect (() => {
                nlist.clear_all ();
                Session.get_instance ().clear ();
            });

            settings_btn.clicked.connect (show_settings);
        }

        return main_box;
    }

    public override void opened () {
        update_clear_all_sensitivity ();
    }

    public override void closed () {
        // We sort the list after closing to avoid sorting during removals
        nlist.invalidate_sort ();
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
            nlist.add_entry (notification);
        }

        set_display_icon_name ();
    }

    private void update_clear_all_sensitivity () {
        clear_all_btn.sensitive = nlist.app_entries.size > 0;
    }

    private void on_notification_closed (uint32 id) {
        foreach (var app_entry in nlist.app_entries.values) {
            foreach (var item in app_entry.app_notifications) {
                if (item.notification.id == id) {
                    item.notification.close ();
                    return;
                }
            }
        }
    }

    private void set_display_icon_name () {
        var dynamic_icon_style_context = dynamic_icon.get_style_context ();
        if (notify_settings.get_boolean ("do-not-disturb")) {
            dynamic_icon_style_context.add_class ("disabled");
        } else if (nlist != null && nlist.app_entries.size > 0) {
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
