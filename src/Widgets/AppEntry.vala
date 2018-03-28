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

public class Notifications.AppEntry : Gtk.ListBoxRow {
    public signal void clear ();

    public AppInfo app_info;
    public List<NotificationEntry> app_notifications;

    public AppEntry (NotificationEntry entry) {
        margin_bottom = 3;
        margin_top = 3;
        margin_start = 12;
        margin_end = 6;

        app_notifications = new List<NotificationEntry> ();
        add_notification_entry (entry);

        var notification = entry.notification;
        app_info = notification.app_info;

        var label = new Gtk.Label (app_info.get_name ());
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var clear_btn_entry = new Gtk.Button.from_icon_name ("edit-clear-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        clear_btn_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        clear_btn_entry.clicked.connect (() => {
            clear ();
        });

        string icon = "";
        if (notification.app_icon == "" && app_info != null) {
            var glib_icon = app_info.get_icon ();
            icon = glib_icon.to_string ();
        } else {
            icon = notification.app_icon;
        }

        var image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.LARGE_TOOLBAR);
        image.pixel_size = 24;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.add (image);
        grid.add (label);
        grid.add (clear_btn_entry);

        add (grid);
        show_all ();
    }

    public Wnck.Window? get_app_window () {
        if (app_notifications.length () == 0) {
            return null;
        }

        var entry = app_notifications.first ().data;
        return entry.notification.get_app_window ();
    }

    public void add_notification_entry (NotificationEntry entry) {
        app_notifications.prepend (entry);
        entry.clear.connect (remove_notification_entry);
    }

    public async void remove_notification_entry (NotificationEntry entry) {
        app_notifications.remove (entry);
        entry.active = false;
        entry.destroy ();

        Session.get_instance ().remove_notification (entry.notification);
        if (app_notifications.length () == 0) {
            clear ();
        }
    }
}
