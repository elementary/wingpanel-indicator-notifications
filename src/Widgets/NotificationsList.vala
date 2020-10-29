/*-
 * Copyright 2015-2020 elementary, Inc (https://elementary.io)
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

public class Notifications.NotificationsList : Gtk.ListBox {
    public signal void close_popover ();

    public Gee.HashMap<string, AppEntry> app_entries { get; private set; }

    construct {
        app_entries = new Gee.HashMap<string, AppEntry> ();

        var placeholder = new Gtk.Label (_("No Notifications"));
        placeholder.margin_top = placeholder.margin_bottom = 24;
        placeholder.margin_start = placeholder.margin_end = 12;
        placeholder.show ();

        unowned Gtk.StyleContext placeholder_style_context = placeholder.get_style_context ();
        placeholder_style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        activate_on_single_click = true;
        selection_mode = Gtk.SelectionMode.NONE;
        set_placeholder (placeholder);
        set_sort_func (sort_func);
        // set_header_func (header_func);
        show_all ();

        row_activated.connect (on_row_activated);
    }

    public void add_entry (Notification notification) {
        if (notification.app_info != null && notification.app_info.get_id () != null) {
            var entry = new NotificationEntry (notification);

            if (app_entries[notification.desktop_id] != null) {
                app_entries[notification.desktop_id].add_notification_entry (entry);
            } else {
                var app_entry = new AppEntry (entry);
                app_entry.clear.connect (clear_app_entry);

                app_entries[notification.desktop_id] = app_entry;
            }

            add (entry);

            show_all ();
            invalidate_sort ();

            Session.get_instance ().add_notification (notification);
        }
    }

    [CCode (instance_pos = -1)]
    private void header_func (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
        unowned string row_id = ((NotificationEntry) row).notification.desktop_id;
        if (before != null) {
            unowned string before_id = ((NotificationEntry) before).notification.desktop_id;
            if (row_id == before_id) {
                row.set_header (null);
            } else {
                row.set_header (app_entries[row_id]);
            }
        } else {
            row.set_header (app_entries[row_id]);
        }
    }

    [CCode (instance_pos = -1)]
    private int sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        unowned Notification notification1 = ((NotificationEntry) row1).notification;
        unowned Notification notification2 = ((NotificationEntry) row2).notification;

        if (notification1.desktop_id != notification2.desktop_id) {
            foreach (unowned NotificationEntry row2_entry in app_entries[notification2.desktop_id].app_notifications) {
                foreach (unowned NotificationEntry row1_entry in app_entries[notification2.desktop_id].app_notifications) {
                    if (row2_entry.notification.timestamp.compare (row1_entry.notification.timestamp) == 1) {
                        return 1;
                    }
                }
            }

            return -1;
        } else {
            return notification2.timestamp.compare (notification1.timestamp);
        }
    }

    public void clear_all () {
        app_entries.clear ();

        Session.get_instance ().clear ();
        close_popover ();
        show_all ();
    }

    private void clear_app_entry (AppEntry app_entry) {
        app_entries.unset (app_entry.app_id);

        app_entry.app_notifications.foreach ((notification_entry) => {
            app_entry.remove_notification_entry.begin (notification_entry);
        });

        app_entry.destroy ();

        if (app_entries.size == 0) {
            clear_all ();
        }
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        bool close = true;

        if (row is AppEntry) {
            var app_entry = (AppEntry)row;
            app_entry.clear ();

        } else if (row is NotificationEntry) {
            unowned NotificationEntry notification_entry = (NotificationEntry) row;
            notification_entry.notification.run_default_action ();
            notification_entry.clear ();

        } else {
            close = false;
        }

        if (close) {
            close_popover ();
        }
    }
}
