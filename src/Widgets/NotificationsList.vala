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

public class NotificationsList : Gtk.Box {
    public signal void switch_stack (bool list);
    private GenericArray<NotificationEntry> items;

    public NotificationsList () {
        this.orientation = Gtk.Orientation.VERTICAL;
        this.margin_start = this.margin_end = 3;
        this.margin_top = 2;

        items = new GenericArray<NotificationEntry> ();
        this.vexpand = true;
        this.show_all ();
    }
    
    public void add_item (NotificationEntry entry) { 
        entry.clear_btn.clicked.connect (() => {
            items.remove (entry);
            this.remove (entry);

            if (items.length == 0)
                clear_all ();
        });

        items.add (entry);
        this.add (entry);
        this.switch_stack (true);

        entry.show_all ();
        this.show_all ();
    }
    
    public int get_items_length () {
        return items.length;
    }
    
    public void clear_all () {
        items.@foreach ((item) => {
            items.remove (item);     
        });

        this.switch_stack (false);
        this.show_all ();
    }
}
