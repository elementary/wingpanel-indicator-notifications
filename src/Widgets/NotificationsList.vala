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

public class NotificationsList : Gtk.ListBox {
    public signal void switch_stack (bool show_list);
    public signal void close_popover ();
    private List<AppEntry> app_entries;
    private List<NotificationEntry> items;
    private HashTable<string, int> table;
    private int counter = 0;

    private static Wnck.Screen screen;

    public NotificationsList () {
        margin_top = 2;

        activate_on_single_click = true;
        selection_mode = Gtk.SelectionMode.NONE;
        row_activated.connect (on_row_activated);

        items = new List<NotificationEntry> ();
        app_entries = new List<AppEntry> ();
        table = new HashTable<string, int> (str_hash, str_equal);

        screen = Wnck.Screen.get_default ();

        vexpand = true;
        show_all ();
    }

    public void add_item (NotificationEntry entry) {
        var app_entry = add_app_entry (entry);

        items.prepend (entry);
        switch_stack (true);

        app_entry.add_notification_entry (entry);
        resort_from_app_entry (app_entry);

        entry.clear.connect (() => {
            destroy_notification_entry (entry);
        });

        app_entry.destroy_entry.connect (() => {
            destroy_app_entry (app_entry);
        });

        counter = counter + 2;

        Session.get_instance ().add_notification (entry.notification);
        entry.show_all ();

        update_separators ();
        show_all ();
    }


    public uint get_items_length () {
        return items.length ();
    }

    public void clear_all () {
        items.@foreach ((item) => {
            items.remove (item);
            remove (item);
            item.active = false;
        });

        app_entries.@foreach ((entry) => {
            app_entries.remove (entry);
            remove (entry);
        });

        counter = 0;

        Session.get_instance ().clear ();
        switch_stack (false);
        close_popover ();
        show_all ();
    }

    private void update_separators () {
        if (get_children ().length () > 0) {
            foreach (var child in get_children ()) {
                if (child is SeparatorEntry) {
                    remove (child);
                }
            }

            foreach (var app_entry in app_entries) {
                if (app_entry.get_index () != 0 && get_children ().nth_data (1) != app_entry) {
                    var row = new SeparatorEntry ();
                    insert (row, app_entry.get_index ());
                }
            }
        }

        show_all ();
    }

    private AppEntry add_app_entry (NotificationEntry entry) {
        AppEntry app_entry;
        bool add = !(entry.notification.desktop_id in construct_desktop_id_list ());
        if (add) {
            var window = get_window_from_entry (entry);
            app_entry = new AppEntry (entry, window);

            screen.active_window_changed.connect (() => {
                if (screen.get_active_window () == app_entry.app_window) {
                    app_entry.clear_btn_entry.clicked ();
                }
            });

            app_entries.append (app_entry);
            prepend (app_entry);
            insert (entry, 1);
            table.insert (app_entry.desktop_id, 0);
        } else {
            app_entry = get_app_entry_from_desktop_id (entry.notification.desktop_id);
            if (app_entry != null) {
                int insert_pos = table.@get (app_entry.desktop_id);
                insert (entry, insert_pos + 1);                
            }
        }

        return app_entry;
    }

    private Wnck.Window? get_window_from_entry (NotificationEntry entry) {
        Wnck.Window? window = null;
        screen.get_windows ().@foreach ((_window) => {
            if (_window.get_pid () == entry.notification.pid) {
                window = _window;
                return;
            }
        });

        return window;
    }

    private async void destroy_notification_entry (NotificationEntry entry) {
        entry.destroy ();
        items.remove (entry);
        entry.active = false;

        Session.get_instance ().remove_notification (entry.notification);
        if (items.length () == 0) {
            clear_all ();
        }
    }

    private void destroy_app_entry (AppEntry app_entry) {
        app_entries.remove (app_entry);

        app_entry.get_notifications ().@foreach ((notification_entry) => {
            notification_entry.destroy ();
            items.remove (notification_entry);
        });

        Idle.add (() => {
            if (app_entry != null) {
                app_entry.destroy ();
            }

            return false;
        });

        if (items.length () == 0) {
            clear_all ();
        }

        update_separators ();
    }

    private void resort_from_app_entry (AppEntry app_entry) {
        if (get_row_at_index (0) != app_entry) {
            remove (app_entry);
            prepend (app_entry);
            int counter = 1;
            app_entry.get_notifications ().@foreach ((notification_entry) => {
                remove (notification_entry);
                add_item (notification_entry);
                counter++;
            });
        }
    }

    private AppEntry? get_app_entry_from_desktop_id (string desktop_id) {
        AppEntry? entry = null;
        app_entries.@foreach ((_entry) => {
            if (_entry.desktop_id == desktop_id) {
                entry = _entry;
                return;
            }
        });

        return entry;
    }

    private string[] construct_desktop_id_list () {
        string[] desktop_id_list = {};
        app_entries.@foreach ((entry) => {
            desktop_id_list += entry.desktop_id;
        });

        return desktop_id_list;
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        if (row.get_path ().get_object_type () == typeof (AppEntry)) {
            if (((AppEntry) row).app_window == null) {
                var window = get_window_from_entry (((AppEntry) row).get_notifications ().nth_data (0));
                if (window != null) {
                    ((AppEntry) row).app_window = window;
                }
            }

            if (((AppEntry) row).app_window != null) {
                ((AppEntry) row).app_window.unminimize (Gtk.get_current_event_time ());
                ((AppEntry) row).clear_btn_entry.clicked ();
                close_popover ();
            } else if (((AppEntry) row).app_info != null) {
                try {
                    ((AppEntry) row).app_info.launch (null, null);
                } catch (Error e) {
                    error ("%s\n", e.message);
                }

                ((AppEntry) row).clear_btn_entry.clicked ();
                close_popover ();
            }
        } else {
            if (((NotificationEntry) row).notification.run_default_action ()) {
                ((NotificationEntry) row).active = false;
                close_popover ();
            }

            ((NotificationEntry) row).clear ();
        }

        update_separators ();
    }
}
