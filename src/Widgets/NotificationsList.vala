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
    public signal void switch_stack (bool show_list);
    public signal void close_popover ();

    private List<AppEntry> app_entries;
    private HashTable<string, int> table;
    private int counter = 0;

    construct {
        app_entries = new List<AppEntry> ();
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

    public void add_entry (NotificationEntry entry) {
        var app_entry = add_entry_internal (entry);
        if (app_entry == null) {
            return;
        }

        switch_stack (true);

        app_entry.clear.connect (clear_app_entry);

        counter += 2;

        Session.get_instance ().add_notification (entry.notification);

        show_all ();
    }


    public unowned List<AppEntry> get_entries () {
        return app_entries;
    }

    public uint get_entries_length () {
        return app_entries.length ();
    }

    public void clear_all () {
        app_entries.foreach ((app_entry) => {
            app_entry.clear ();
        });

        counter = 0;

        Session.get_instance ().clear ();
        switch_stack (false);
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

    private AppEntry? add_entry_internal (NotificationEntry entry) {
        if (entry.notification.app_info == null ||
            entry.notification.app_info.get_id () == null) {
            return null;
        }

        AppEntry? app_entry = null;
        string[] desktop_id_list = {};
        app_entries.foreach ((_app_entry) => {
            var app_id = _app_entry.app_info.get_id ();

            desktop_id_list += app_id;

            if (app_id == entry.notification.desktop_id && app_entry == null) {
                app_entry = _app_entry;
            }
        });

        if (!(entry.notification.desktop_id in desktop_id_list)) {
            app_entry = new AppEntry (entry);

            app_entries.append (app_entry);
            prepend (app_entry);
            insert (entry, 1);
            table.insert (app_entry.app_info.get_id (), 0);
        } else if (app_entry != null) {
            resort_app_entry (app_entry);
            app_entry.add_notification_entry (entry);

            int insert_pos = table.get (app_entry.app_info.get_id ());
            insert (entry, insert_pos + 1);
        }

        return app_entry;
    }

    private void clear_app_entry (AppEntry app_entry) {
        app_entries.remove (app_entry);

        app_entry.app_notifications.foreach ((notification_entry) => {
            app_entry.remove_notification_entry.begin (notification_entry);
        });

        app_entry.destroy ();

        if (get_entries_length () == 0) {
            clear_all ();
        }
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        bool close = true;

        if (row is AppEntry) {
            var app_entry = (AppEntry)row;
            app_entry.clear ();

        } else if (row is NotificationEntry) {
            var notification_entry = (NotificationEntry)row;
            notification_entry.clear ();

        } else {
            close = false;
        }

        if (close) {
            close_popover ();
        }
    }
}
