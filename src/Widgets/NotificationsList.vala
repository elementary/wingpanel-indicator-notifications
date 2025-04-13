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
    public enum UpdateKind {
        COLLAPSE,
        EXPAND,
        DISMISS
    }

    public signal void close_popover ();

    public const string ACTION_GROUP_PREFIX = "notifications-list";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    public const string INTERNAL_ACTION_PREFIX = "notifications-list-custom.";
    public const string ACTION_UPDATE_SECTION = "update-section";

    class construct {
        install_action (INTERNAL_ACTION_PREFIX + ACTION_UPDATE_SECTION, "(uuu)", on_update_section);
    }

    private NotificationManager manager;

    construct {
        manager = new NotificationManager ();

        var selection_model = new Gtk.NoSelection (manager.notifications);

        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect (setup);
        factory.bind.connect (bind);
        factory.unbind.connect (unbind);

        var header_factory = new Gtk.SignalListItemFactory ();
        header_factory.setup.connect (setup_header);
        header_factory.bind.connect (bind_header);

        var list_view = new Gtk.ListView (selection_model, factory) {
            header_factory = header_factory,
        };

        var scrolled = new Gtk.ScrolledWindow () {
            child = list_view,
            hscrollbar_policy = NEVER,
            max_content_height = 500,
            propagate_natural_height = true
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

    private void unbind (Object obj) {
        var item = (Gtk.ListItem) obj;
        var entry = (NotificationEntry) item.child;
        entry.unbind ();
    }

    private void setup_header (Object obj) {
        var item = (Gtk.ListHeader) obj;
        item.child = new AppEntry (item);
    }

    private void bind_header (Object obj) {
        var item = (Gtk.ListHeader) obj;
        var entry = (AppEntry) item.child;
        var notification = (Notification) item.item;
        entry.bind (notification);
    }

    public void update_section (uint start, uint end, UpdateKind kind) {
        for (uint i = start; i < end; i++) {
            var notification = (Notification) manager.notifications.get_item (i);

            switch (kind) {
                case COLLAPSE:
                case EXPAND:
                    notification.collapsed = (kind == COLLAPSE);
                    break;

                case DISMISS:
                    activate_action_variant (ACTION_PREFIX + notification.dismiss_action_name, null);
                    break;
            }
        }
    }

    private static void on_update_section (Gtk.Widget widget, string action, Variant? parameters) {
        var list = (NotificationsList) widget;
        uint start, end, kind;
        parameters.get ("(uuu)", out start, out end, out kind);
        list.update_section (start, end, (UpdateKind) kind);
    }
}
