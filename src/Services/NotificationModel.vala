/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Notifications.NotificationModel : Object, ListModel {
    [DBus (name = "io.elementary.portal.NotificationProvider")]
    private interface Provider : Object {
        public signal void items_changed (uint pos, uint removed, uint added);

        public abstract async uint get_n_items () throws DBusError, IOError;
        public abstract async Notification.Data get_notification (uint pos) throws DBusError, IOError;
    }

    public const uint REMOVAL_ANIMATION = 300;

    public ActionGroup action_group { get; construct; }
    public uint n_notifications { get { return store.n_items; } }
    public uint n_apps { get; private set; default = 0; }

    private Gee.List<uint> sorted;
    private ListStore store;

    private Provider? provider;

    construct {
        sorted = new Gee.LinkedList<uint> ();

        store = new ListStore (typeof (Notification));
        store.items_changed.connect (on_store_items_changed);

        action_group = DBusActionGroup.get (
            Application.get_default ().get_dbus_connection (),
            "org.freedesktop.impl.portal.desktop.pantheon",
            "/io/elementary/portal/NotificationProvider"
        );

        Bus.watch_name (SESSION, "org.freedesktop.impl.portal.desktop.pantheon", NONE, () => connect_to_provider.begin (), () => {
            provider = null;
            store.remove_all ();
        });
    }

    private async void connect_to_provider () {
        try {
            provider = yield Bus.get_proxy<Provider> (SESSION, "org.freedesktop.impl.portal.desktop.pantheon", "/io/elementary/portal/NotificationProvider");
            for (uint i = 0; i < yield provider.get_n_items (); i++) {
                yield on_items_changed (i, 0, 1);
            }
            provider.items_changed.connect (on_items_changed);
        } catch (Error e) {
            warning ("Failed to get provider: %s", e.message);
        }
    }

    // We only have three types of updates:
    // pos, 0, 1 (completely new notification)
    // pos, 1, 0 (notification dismissed)
    // pos, 1, 1 (notification replaced)
    private async void on_items_changed (uint pos, uint removed, uint added) {
        pos = adjust_position (pos);

        Notification[] added_notification = new Notification[added];

        for (uint i = 0; i < added; i++) {
            try {
                var notification_data = yield provider.get_notification (pos + i);
                added_notification[i] = (new Notification (notification_data));
            } catch (Error e) {
                warning ("Failed to get notification: %s", e.message);
                continue;
            }
        }

        if (added == 0 && removed == 1) {
            delay_removal (pos);
        } else {
            store.splice (pos, removed, added_notification);
        }
    }

    private uint adjust_position (uint pos) {
        var item = (Notification) store.get_item (pos);
        while (item != null && item.collapsed) {
            pos++;
            item = (Notification) store.get_item (pos);
        }
        return pos;
    }

    private void delay_removal (uint pos) {
        var removed_notification = (Notification) store.get_item (pos);
        removed_notification.collapsed = true;

        Timeout.add (REMOVAL_ANIMATION, () => {
            uint current_position;
            store.find (removed_notification, out current_position);
            store.remove (current_position);
            return Source.REMOVE;
        });
    }

    private void on_store_items_changed (uint pos, uint removed, uint added) {
        if (added == 0) {
            var removal_pos = sorted.index_of (pos);
            sorted.remove (pos);

            shift (pos, -1);

            items_changed (removal_pos, 1, 0);
        } else if (added == 1 && removed == 0) {
            shift (pos, 1);

            var notification = (Notification) store.get_item (pos);
            var app_id = notification.app_id;

            var section_iter = sorted.filter ((i) => {
                return ((Notification) store.get_item (i)).app_id == app_id;
            });

            var section = new Gee.LinkedList<uint> ();
            section.add_all_iterator (section_iter);

            if (section.size > 0) {
                var removal_pos = sorted.index_of (section.first ());
                sorted.remove_all (section);

                items_changed (removal_pos, section.size, 0);
            }

            section.insert (0, pos);

            sorted.insert_all (0, section);

            items_changed (0, 0, section.size);
        } else if (added == 1 && removed == 1) {
            var change_pos = sorted.index_of (pos);
            items_changed (change_pos, 1, 1);
        } else {
            critical ("Unexpected change occured in the backing store");
        }

        notify_property ("n-notifications");
    }

    private void shift (uint from, uint by) {
        var iter = sorted.list_iterator ();
        while (iter.next ()) {
            var current_pos = iter.get ();
            if (current_pos >= from) {
                iter.set (current_pos + by);
            }
        }
    }

    public Object? get_item (uint pos) {
        return store.get_item (sorted[(int) pos]);
    }

    public uint get_n_items () {
        return store.n_items;
    }

    public Type get_item_type () {
        return typeof (Notification);
    }
}
