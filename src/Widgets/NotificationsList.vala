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

        var placeholder = new Gtk.Label (_("No Notifications")) {
            margin_top = 24,
            margin_bottom = 24,
            margin_start = 12,
            margin_end = 12,
            visible = true
        };

        unowned Gtk.StyleContext placeholder_style_context = placeholder.get_style_context ();
        placeholder_style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        selection_mode = Gtk.SelectionMode.NONE;
        set_placeholder (placeholder);
        show_all ();
    }

    public void add_entry (Notification notification) {
        var entry = new NotificationEntry (notification);

        if (app_entries[notification.desktop_id] != null) {
            var app_entry = app_entries[notification.desktop_id];

            resort_app_entry (app_entry);
            app_entry.add_notification_entry (entry);

            int insert_pos = table.get (app_entry.app_id);
            insert (entry, insert_pos + 1);
        } else {
            var app_entry = new AppEntry (notification.app_info);
            app_entry.add_notification_entry (entry);
            app_entry.clear.connect (clear_app_entry);

            app_entries[notification.desktop_id] = app_entry;

            prepend (app_entry);
            insert (entry, 1);
            table.insert (app_entry.app_id, 0);
        }

        show_all ();

        Session.get_instance ().add_notification (notification);
    }

    public void clear_all () {
        var iter = app_entries.map_iterator ();
        while (iter.next ()) {
            var entry = iter.get_value ();
            iter.unset ();
            clear_app_entry (entry);
        }

        close_popover ();
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
        app_entry.clear.disconnect (clear_app_entry);

        app_entries.unset (app_entry.app_id);

        app_entry.clear_all_notification_entries ();

        app_entry.destroy ();

        if (app_entries.size == 0) {
            Session.get_instance ().clear ();
        }
    }
}
