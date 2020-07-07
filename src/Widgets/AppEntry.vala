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

    public NotificationEntry entry { get; construct; }
    public AppInfo? app_info = null;
    public List<NotificationEntry> app_notifications;

    public AppEntry (NotificationEntry entry) {
        Object (entry: entry);
    }

    construct {
        margin = 12;
        margin_top = 6;

        app_notifications = new List<NotificationEntry> ();
        add_notification_entry (entry);

        var notification = entry.notification;
        app_info = notification.app_info;

        var label = new Gtk.Label (app_info.get_name ());
        label.hexpand = true;
        label.xalign = 0;
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var clear_btn_entry = new Gtk.Button.from_icon_name ("edit-clear-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        clear_btn_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        clear_btn_entry.clicked.connect (() => {
            clear ();
        });

        var image = new Gtk.Image ();
        image.pixel_size = 24;

        if (notification.app_icon == "" && app_info != null) {
            image.gicon = app_info.get_icon ();
        } else {
            image.icon_name = notification.app_icon;
        }

        var grid = new Gtk.Grid ();
        grid.column_spacing = 6;
        grid.add (image);
        grid.add (label);
        grid.add (clear_btn_entry);

        add (grid);
        show_all ();
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
