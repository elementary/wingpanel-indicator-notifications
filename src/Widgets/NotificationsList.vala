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

    private HashTable<string, int> table;

    construct {
        app_entries = new Gee.HashMap<string, AppEntry> ();
        table = new HashTable<string, int> (str_hash, str_equal);

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
        show_all ();

        row_activated.connect (on_row_activated);
    }

    public void add_entry (Notification notification) {
        if (notification.app_info != null && notification.app_info.get_id () != null) {
            AppEntry? app_entry = null;

            if (app_entries[notification.desktop_id] != null) {
                app_entry = app_entries[notification.desktop_id];
            }

            var entry = new NotificationEntry (notification);
            if (app_entry == null) {
                app_entry = new AppEntry (entry);
                app_entries[notification.desktop_id] = app_entry;

                prepend (app_entry);
                insert (entry, 1);
                table.insert (app_entry.app_id, 0);
            } else {
                resort_app_entry (app_entry);
                app_entry.add_notification_entry (entry);

                int insert_pos = table.get (app_entry.app_id);
                insert (entry, insert_pos + 1);
            }

            app_entry.clear.connect (clear_app_entry);

            show_all ();

            Session.get_instance ().add_notification (notification);
        }
    }

    public void clear_all () {
        app_entries.values.foreach ((app_entry) => {
            clear_app_entry (app_entry);
            return true;
        });

        Session.get_instance ().clear ();
        close_popover ();
        show_all ();
    }

    private void resort_app_entry (AppEntry app_entry) {
        if (get_row_at_index (0) != app_entry) {
            remove (app_entry);
            prepend (app_entry);
            app_entry.app_notifications.foreach ((notification_entry) => {
                remove (notification_entry);
                insert (notification_entry, 1);
            });
        }
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
