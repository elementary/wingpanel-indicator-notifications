/*-
 * Copyright 2015-2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Notifications.AppEntry : Gtk.ListBoxRow {
    public signal void clear ();

    public string app_id { get; private set; }
    public AppInfo? app_info { get; construct; default = null; }
    public List<NotificationEntry> app_notifications;

    public AppEntry (AppInfo? app_info) {
        Object (app_info: app_info);
    }

    construct {
        margin = 12;
        margin_bottom = 3;
        margin_top = 6;

        app_notifications = new List<NotificationEntry> ();

        unowned string name;
        if (app_info != null) {
            app_id = app_info.get_id ();
            name = app_info.get_name ();
        } else {
            app_id = "other";
            name = _("Other");
        }

        var label = new Gtk.Label (name) {
            hexpand = true,
            xalign = 0
        };
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var clear_btn_entry = new Gtk.Button.from_icon_name ("edit-clear-all-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
            tooltip_text = _("Clear all %s notifications").printf (name)
        };
        clear_btn_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var grid = new Gtk.Grid () {
            column_spacing = 6
        };
        grid.add (label);
        grid.add (clear_btn_entry);

        add (grid);
        show_all ();

        clear_btn_entry.clicked.connect (() => {
            clear (); // Causes notification list to destroy this app entry after clearing its notification entries
        });
    }

    public void add_notification_entry (NotificationEntry entry) {
        app_notifications.prepend (entry);
        entry.clear.connect (remove_notification_entry);
    }

    public void remove_notification_entry (NotificationEntry entry) {
        app_notifications.remove (entry);
        entry.dismiss ();

        Session.get_instance ().remove_notification (entry.notification);
        if (app_notifications.length () == 0) {
            clear ();
        }
    }

    public void clear_all_notification_entries () {
        Notification[] to_remove = {};
        app_notifications.@foreach ((entry) => {
            entry.dismiss ();
            to_remove += entry.notification;
        });

        app_notifications = new List<NotificationEntry> ();
        Session.get_instance ().remove_notifications (to_remove);
    }
}
