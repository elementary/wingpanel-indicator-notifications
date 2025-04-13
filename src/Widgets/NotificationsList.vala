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

public class Notifications.NotificationsList : Granite.Bin {
    public signal void close_popover ();

    public const string ACTION_GROUP_PREFIX = "notifications-list";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    // add action update section with uuu, so start, end, kind (COLLAPSE, EXPAND, DISMISS) for headers

    private NotificationManager manager;

    construct {
        manager = new NotificationManager ();

        var sort_model = new Gtk.SortListModel (manager.notifications, null);

        var selection_model = new Gtk.NoSelection (sort_model);

        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect (setup);
        factory.bind.connect (bind);

        var list_view = new Gtk.ListView (selection_model, factory);

        var scrolled = new Gtk.ScrolledWindow () {
            child = list_view
        };

        child = scrolled;

        insert_action_group (ACTION_GROUP_PREFIX, manager.action_group);
    }

    private void setup (Object obj) {
        var item = (Gtk.ListItem) obj;
        item.child = new NotificationEntry ();
    }

    private void bind (Object obj) {
        var item = (Gtk.ListItem) obj;
        var entry = (NotificationEntry) item.child;
        var notification = (Notification) item.item;
        entry.bind (notification);
    }
}
