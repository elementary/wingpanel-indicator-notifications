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

public class Notifications.NotificationsList : Gtk.ListBox {
    public signal void switch_stack (bool show_list);
    public signal void close_popover ();

    public unowned List<AppEntry> app_entries { get; private set; }

    private HashTable<string, int> table;
    private int counter = 0;

    public NotificationsList () {
        margin_top = 2;

        activate_on_single_click = true;
        selection_mode = Gtk.SelectionMode.NONE;
        row_activated.connect (on_row_activated);

        app_entries = new List<AppEntry> ();
        table = new HashTable<string, int> (str_hash, str_equal);

        vexpand = true;
        show_all ();
    }

    construct {
        var placeholder = new Gtk.Label (_("No Notifications"));
        placeholder.margin_top = placeholder.margin_bottom = 24;
        placeholder.margin_start = placeholder.margin_end = 12;
        placeholder.show ();

        unowned Gtk.StyleContext placeholder_style_context = placeholder.get_style_context ();
        placeholder_style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        set_placeholder (placeholder);
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

        update_separators ();
        show_all ();
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

    private void update_separators () {
        if (get_children ().length () > 0) {
            foreach (var child in get_children ()) {
                if (child is SeparatorEntry) {
                    remove (child);
                }
            }

            foreach (unowned AppEntry app_entry in app_entries) {
                if (app_entry.get_index () != 0 && get_children ().nth_data (1) != app_entry) {
                    var row = new SeparatorEntry ();
                    insert (row, app_entry.get_index ());
                }
            }
        }

        show_all ();
    }

    private AppEntry? add_entry_internal (NotificationEntry entry) {
        if (entry.notification.app_info == null ||
            entry.notification.app_info.get_id () == null) {
            return null;
        }

        AppEntry? app_entry = null;
        bool add = !(entry.notification.desktop_id in construct_desktop_id_list ());
        if (add) {
            app_entry = new AppEntry (entry);

            app_entries.append (app_entry);
            prepend (app_entry);
            insert (entry, 1);
            table.insert (app_entry.app_info.get_id (), 0);
        } else {
            app_entry = get_app_entry_from_desktop_id (entry.notification.desktop_id);

            if (app_entry != null) {
                resort_app_entry (app_entry);
                app_entry.add_notification_entry (entry);

                int insert_pos = table.get (app_entry.app_info.get_id ());
                insert (entry, insert_pos + 1);
            }
        }

        return app_entry;
    }

    private void clear_app_entry (AppEntry app_entry) {
        app_entries.remove (app_entry);

        app_entry.app_notifications.foreach ((notification_entry) => {
            app_entry.remove_notification_entry.begin (notification_entry);
        });

        app_entry.destroy ();
        update_separators ();

        if (app_entries.length () == 0) {
            clear_all ();
        }
    }

    private AppEntry? get_app_entry_from_desktop_id (string desktop_id) {
        AppEntry? app_entry = null;
        app_entries.foreach ((_app_entry) => {
            if (_app_entry.app_info.get_id () == desktop_id && app_entry == null) {
                app_entry = _app_entry;
            }
        });

        return app_entry;
    }

    private string[] construct_desktop_id_list () {
        string[] desktop_id_list = {};
        app_entries.foreach ((app_entry) => {
            desktop_id_list += app_entry.app_info.get_id ();
        });

        return desktop_id_list;
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

        update_separators ();
    }
}
