/*-
 * Copyright (c) 2015 Wingpanel Developers (http://launchpad.net/wingpanel)
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
    private const string CHILD_SCHEMA_ID = "org.pantheon.desktop.gala.notifications.application";
    private const string CHILD_PATH = "/org/pantheon/desktop/gala/notifications/applications/%s/";
    private const string REMEMBER_KEY = "remember";

    private const uint16 BOX_WIDTH = 300;
    private const uint16 BOX_HEIGHT = 400;
    private const string LIST_ID = "list";
    private const string NO_NOTIFICATIONS_ID = "no-notifications";

    private Gtk.Spinner? dynamic_icon = null;
    private Gtk.Box? main_box = null;
    private Gtk.ModelButton clear_all_btn;
    private Wingpanel.Widgets.Switch not_disturb_switch;

    private NotificationsList nlist;

    private Gee.HashMap<string, Settings> app_settings_cache;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.MESSAGES,
                display_name: _("Notifications indicator"),
                description:_("The notifications indicator"));

        visible = true;
    }

    public override Gtk.Widget get_display_widget () {
        if (dynamic_icon == null) {
            nlist = new NotificationsList ();
            // this is needed initially to always update the state of the indicator
            nlist.switch_stack.connect (set_display_icon_name);

            restore_previous_session ();

            dynamic_icon = new Gtk.Spinner ();
            dynamic_icon.active = true;
            dynamic_icon.get_style_context ().add_class ("notification-icon");
            dynamic_icon.button_press_event.connect ((e) => {
                if (e.button == Gdk.BUTTON_MIDDLE) {
                    NotifySettings.get_instance ().do_not_disturb = !NotifySettings.get_instance ().do_not_disturb;
                    return Gdk.EVENT_STOP;
                }
    
                return Gdk.EVENT_PROPAGATE;
            });    

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("io/elementary/wingpanel/notifications/indicator.css");
            dynamic_icon.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var monitor = NotificationMonitor.get_instance ();
            monitor.notification_received.connect (on_notification_received);
            monitor.notification_closed.connect (on_notification_closed);

            NotifySettings.get_instance ().changed[NotifySettings.DO_NOT_DISTURB_KEY].connect (() => {
                if (not_disturb_switch != null) {
                    not_disturb_switch.get_switch ().active = NotifySettings.get_instance ().do_not_disturb;
                }

                set_display_icon_name ();
            });

            set_display_icon_name ();
        }

        return dynamic_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (main_box == null) {
            app_settings_cache = new Gee.HashMap<string, Settings> ();

            main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            main_box.set_size_request (BOX_WIDTH, -1);

            var no_notifications_label = new Gtk.Label (_("No Notifications"));
            no_notifications_label.get_style_context ().add_class ("h2");
            no_notifications_label.sensitive = false;
            no_notifications_label.margin_top = no_notifications_label.margin_bottom = 24;
            no_notifications_label.margin_start = no_notifications_label.margin_end = 12;

            var scrolled = new Wingpanel.Widgets.AutomaticScrollBox (null, null);
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scrolled.add (nlist);

            not_disturb_switch = new Wingpanel.Widgets.Switch (_("Do Not Disturb"), NotifySettings.get_instance ().do_not_disturb);
            not_disturb_switch.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            not_disturb_switch.get_switch ().notify["active"].connect (() => {
                NotifySettings.get_instance ().do_not_disturb = not_disturb_switch.get_switch ().active;
            });

            clear_all_btn = new Gtk.ModelButton ();
            clear_all_btn.text = _("Clear All Notifications");
            clear_all_btn.clicked.connect (() => {
                nlist.clear_all ();
                Session.get_instance ().clear ();
            });

            var settings_btn = new Gtk.ModelButton ();
            settings_btn.text = _("Notifications Settings…");
            settings_btn.clicked.connect (show_settings);

            nlist.close_popover.connect (() => close ());
            nlist.switch_stack.connect (update_clear_all_sensitivity);

            main_box.add (not_disturb_switch);
            main_box.add (new Wingpanel.Widgets.Separator ());
            main_box.add (scrolled);
            main_box.add (new Wingpanel.Widgets.Separator ());
            main_box.pack_end (settings_btn, false, false, 0);
            main_box.pack_end (clear_all_btn, false, false, 0);
            main_box.show_all ();

            update_clear_all_sensitivity (nlist.get_entries_length () > 0);
        }

        return main_box;
    }

    public override void opened () {

    }

    public override void closed () {

    }

    private void on_notification_received (DBusMessage message, uint32 id) {
        var notification = new Notification.from_message (message, id);
        if (!notification.get_is_valid () || notification.app_name in EXCEPTIONS) {
            return;
        }

        string app_id = notification.desktop_id.replace (Notification.DESKTOP_ID_EXT, "");
        if (!((DesktopAppInfo)notification.app_info).get_boolean ("X-GNOME-UsesNotifications")) {
            app_id = "gala-other";
        }

        Settings? app_settings = app_settings_cache.get (app_id);

        var schema = SettingsSchemaSource.get_default ().lookup (CHILD_SCHEMA_ID, true);
        if (schema != null && app_settings == null && app_id != "") {
            app_settings = new Settings.full (schema, null, CHILD_PATH.printf (app_id));
            app_settings_cache.set (app_id, app_settings);
        }

        if (app_settings == null || app_settings.get_boolean (REMEMBER_KEY)) {
            var entry = new NotificationEntry (notification);
            nlist.add_entry (entry);
        }

        set_display_icon_name ();        
    }

    private void update_clear_all_sensitivity (bool show_list) {
        clear_all_btn.sensitive = show_list;
    }

    private void on_notification_closed (uint32 id) {
        foreach (var app_entry in nlist.get_entries ()) {
            foreach (var item in app_entry.app_notifications) {
                if (item.notification.id == id) {
                    item.notification.close ();
                    return;
                }
            }
        }
    }

    private void restore_previous_session () {
        var previous_session = Session.get_instance ().get_session_notifications ();
        previous_session.foreach ((notification) => {
            nlist.add_entry (new NotificationEntry (notification));
        });
    }

    private void set_display_icon_name () {
        var dynamic_icon_style_context = dynamic_icon.get_style_context ();
        if (NotifySettings.get_instance ().do_not_disturb) {
            dynamic_icon_style_context.add_class ("disabled");
        } else if (nlist != null && nlist.get_entries_length () > 0) {
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
