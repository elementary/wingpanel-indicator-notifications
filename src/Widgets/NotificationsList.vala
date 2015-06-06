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
    public signal void switch_stack (bool list);
    private List<AppEntry> app_entries;
    private List<NotificationEntry> items;
    private HashTable<string, int> table;
    private int counter = 0;

    public NotificationsList () {
        this.margin_start = this.margin_end = 3;
        this.margin_top = 2;

        this.activate_on_single_click = false;
        this.selection_mode = Gtk.SelectionMode.NONE;
        this.row_activated.connect (on_row_activated);

        items = new List<NotificationEntry> ();
        app_entries = new List<AppEntry> ();
        table = new HashTable<string, int> (str_hash, str_equal);

        this.vexpand = true;
        this.show_all ();
    }
    
    public void add_item (NotificationEntry entry) { 
        if (entry.notification.app_name == "notify-send" || entry.notification.app_name == "") {
            entry.notification.display_name = _("Others");
            entry.notification.app_icon = "dialog-information";
        }

        bool add_app_entry = !(entry.notification.app_name in construct_app_names ());
        AppEntry app_entry;
        if (add_app_entry) {
            app_entry = new AppEntry (entry);
            app_entries.append (app_entry);
            this.insert (app_entry, counter);

            if (counter == 0)
                app_entry.separator.destroy ();

            this.insert (entry, counter + 2);
            table.insert (app_entry.app_name, counter + 1);
        } else {
            app_entry = get_app_entry_from_app_name (entry.notification.app_name);
            int insert_pos = table.@get (app_entry.app_name);
            this.insert (entry, insert_pos + 1);
        }

        app_entry.destroy.connect (() => {
            app_entries.remove (app_entry);
        });

        items.append (entry);
        this.switch_stack (true);

        entry.clear_btn.clicked.connect (() => {
            this.remove (entry);
            items.remove (entry);
            entry.active = false;

            if (items.length () == 0)
                clear_all ();
            else 
                (this.get_row_at_y (0) as AppEntry).separator.destroy ();   
        });

        app_entry.add_notification_entry (entry);

        counter = counter + 2;
        entry.show_all ();
        this.show_all ();
    }
    
    private AppEntry? get_app_entry_from_app_name (string app_name) {
        AppEntry? entry = null;
        app_entries.@foreach ((_entry) => {
             if (_entry.app_name == app_name)
                entry = _entry;      
        }); 

        return entry;
    }

    private string[] construct_app_names () {
        string[] app_names = {};
        app_entries.@foreach ((entry) => {
             app_names += entry.app_name;
        });

        return app_names;
    }

    public uint get_items_length () {
        return items.length ();
    }
    
    public void clear_all () {
        items.@foreach ((item) => {
            items.remove (item);
            this.remove (item);
            item.active = false;
        });

        app_entries.@foreach ((entry) => {
            app_entries.remove (entry);
            this.remove (entry);    
        });

        counter = 0;

        this.switch_stack (false);
        this.show_all ();
    }

    private void on_row_activated (Gtk.ListBoxRow row) {

    }
}
