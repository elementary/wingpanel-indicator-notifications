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

public class AppEntry : Gtk.ListBoxRow {
    public string app_name;
    public Gtk.Button clear_btn_entry;
    public AppInfo? app_info = null;
    public Wnck.Window? app_window;

    public signal void destroy_entry ();

    private List<NotificationEntry> app_notifications;
    private string display_name;

    public AppEntry (NotificationEntry entry, Wnck.Window? _app_window) {
        margin_bottom = 3;
        margin_top = 3;
        margin_start = 12;
        margin_end = 6;

        var notification = entry.notification;
        app_name = notification.app_name;
        app_window = _app_window;
        app_info = notification.app_info;

        app_notifications = new List<NotificationEntry> ();
        add_notification_entry (entry);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);

        /* Capitalize the first letter */
        char[] utf8 = notification.display_name.to_utf8 ();
        utf8[0] = utf8[0].toupper ();

        if (app_info != null) {
            display_name = app_info.get_name ();
        } else {
            display_name = string.join ("", utf8);
        }

        var label = new Gtk.Label (display_name);
        label.get_style_context ().add_class ("h3");

        clear_btn_entry = new Gtk.Button.from_icon_name ("edit-clear-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        clear_btn_entry.get_style_context ().add_class ("flat");
        clear_btn_entry.clicked.connect (() => {
            destroy_entry ();
        });

        string icon = "";
        if (notification.app_icon == "" && app_info != null) {
            var glib_icon = app_info.get_icon ();
            icon = glib_icon.to_string ();
        } else {
            icon = notification.app_icon;
        }

        var image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.LARGE_TOOLBAR);
        hbox.pack_start (image, false, false, 0);
        hbox.pack_start (label, false, false, 0);
        hbox.pack_end (clear_btn_entry, false, false, 0);

        connect_entry (entry);

        add (hbox);
        show_all ();
    }

    private void connect_entry (NotificationEntry entry) {
        entry.clear.connect (() => {
            if (entry != null) {
                remove_notification_entry (entry);
            }
        });
    }

    public unowned List<NotificationEntry> get_notifications () {
        return app_notifications;
    }

    public void add_notification_entry (NotificationEntry entry) {
        app_notifications.prepend (entry);
        connect_entry (entry);
    }

    public void remove_notification_entry (NotificationEntry entry) {
        app_notifications.remove (entry);
        if (app_notifications.length () == 0) {
            destroy_entry ();
        }
    }
}
