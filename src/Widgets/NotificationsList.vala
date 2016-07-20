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

        monitor_active_window ();
    }

    public void add_entry (NotificationEntry entry) {
        var app_entry = add_app_entry (entry);
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

    private AppEntry? add_app_entry (NotificationEntry entry) {
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
                app_entry.add_notification_entry (entry);

                int insert_pos = table.get (app_entry.app_info.get_id ());
                insert (entry, insert_pos + 1);                
            }
        }

        return app_entry;
    }

    private void monitor_active_window () {
        var screen = Wnck.Screen.get_default ();
        screen.active_window_changed.connect (() => {
            app_entries.foreach ((app_entry) => {
                if (screen.get_active_window () == app_entry.get_app_window ()) {
                    app_entry.clear ();
                }
            });
        });
    }

    private void clear_app_entry (AppEntry app_entry) {
        app_entries.remove (app_entry);

        app_entry.app_notifications.foreach ((notification_entry) => {
            app_entry.remove_notification_entry.begin (notification_entry);
        });

        app_entry.destroy ();
        update_separators ();

        if (get_entries_length () == 0) {
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
            close = focus_notification_app (app_entry.get_app_window (),
                                            app_entry.app_info);

            app_entry.clear ();
        } else if (row is NotificationEntry) {
            var notification_entry = (NotificationEntry)row;

            if (!notification_entry.notification.run_default_action ()) {
                close = focus_notification_app (notification_entry.notification.get_app_window (),
                                                notification_entry.notification.app_info);
            }

            notification_entry.clear ();
        } else {
            close = false;
        }

        if (close) {
            close_popover ();
        }

        update_separators ();
    }

    private bool focus_notification_app (Wnck.Window? app_window, AppInfo? app_info) {
        if (app_window != null) {
            app_window.unminimize (Gtk.get_current_event_time ());
            return true;
        } else if (app_info != null) {
            try {
                app_info.launch (null, null);
                return true;
            } catch (Error e) {
                warning ("%s\n", e.message);
            }            
        }

        return false;
    }
}
