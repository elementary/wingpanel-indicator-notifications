/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

/**
 * This is the sorted model that holds all our notifications.
 * The structure consists of multiple ListModel concepts:
 * provider -> store -> #this
 * Each stage only depends on the one directly before it and reflects its and only its changes.
 *
 * The store "passes through" (it actually caches them) the notifications of the provider.
 * The only difference is that when notifications are removed from the provider we don't
 * immediately remove them from the store but instead mark them as removed and only really remove
 * them after a timeout. This is to allow for animations to be shown.
 *
 * #this passes through the notifications from the store but with a sorting applied.
 * The sorting is in sections of apps where the app section with the newest notification
 * comes first. Within a section the notifications are sorted by timestamp.
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
    public uint n_notifications { get { return sorting.size; } }
    public uint n_apps { get; private set; default = 0; }

    private Gee.List<uint> sorting;
    private ListStore store;
    private Provider? provider;

    construct {
        action_group = DBusActionGroup.get (
            Application.get_default ().get_dbus_connection (),
            "org.freedesktop.impl.portal.desktop.pantheon",
            "/io/elementary/portal/NotificationProvider"
        );

        sorting = new Gee.LinkedList<uint> ();

        store = new ListStore (typeof (Notification));
        store.items_changed.connect (on_store_items_changed);

        Bus.watch_name (SESSION, "org.freedesktop.impl.portal.desktop.pantheon", NONE, () => connect_to_provider.begin (), () => {
            provider = null;
            store.remove_all ();
        });
    }

    private async void connect_to_provider () {
        try {
            provider = yield Bus.get_proxy<Provider> (SESSION, "org.freedesktop.impl.portal.desktop.pantheon", "/io/elementary/portal/NotificationProvider");
            yield on_provider_items_changed (0, 0, yield provider.get_n_items ());
            provider.items_changed.connect (on_provider_items_changed);
        } catch (Error e) {
            warning ("Failed to get provider: %s", e.message);
        }
    }

    // store

    private async void on_provider_items_changed (uint pos, uint removed, uint added) {
        pos = adjust_position (pos);

        Notification[] added_notification = new Notification[added];

        for (uint i = 0; i < added; i++) {
            try {
                var data = yield provider.get_notification (pos + i);
                added_notification[i] = (new Notification (data));
            } catch (Error e) {
                warning ("Failed to get notification: %s", e.message);
                continue;
            }
        }

        if (added == removed) { // We assume all were just replaced
            store.splice (pos, removed, added_notification);
        } else { // We assume none were just replaced
            for (uint i = 0; i < removed; i++) {
                delay_removal (pos);
            }

            if (added_notification.length > 0) {
                store.splice (0, 0, added_notification);
            }
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

    // this

    /**
     * Keep our sorting up to date. We have fast paths for the most common
     * cases (notification added, notification removed, notification replaced).
     * Other cases should pretty much never happen, but we handle them anyway.
     */
    private void on_store_items_changed (uint pos, uint removed, uint added) {
        if (added == 0 && removed == 1) { // Notification dismissed
            var removal_pos = sorting.index_of (pos);
            sorting.remove (pos);

            shift (pos, -1);

            items_changed (removal_pos, 1, 0);
        } else if (added == 1 && removed == 0) { // Notification added
            shift (pos, 1);

            var notification = (Notification) store.get_item (pos);
            var app_id = notification.app_id;

            var section_iter = sorting.filter ((i) => {
                return ((Notification) store.get_item (i)).app_id == app_id;
            });

            var section = new Gee.LinkedList<uint> ();
            section.add_all_iterator (section_iter);

            if (section.size > 0) {
                var removal_pos = sorting.index_of (section.first ());
                sorting.remove_all (section);

                items_changed (removal_pos, section.size, 0);
            }

            section.insert (0, pos);

            sorting.insert_all (0, section);

            items_changed (0, 0, section.size);
        } else if (added == 1 && removed == 1) { // Notification replaced (without SHOW_AS_NEW)
            var change_pos = sorting.index_of (pos);
            items_changed (change_pos, 1, 1);
        } else { // This shouldn't happen (except on first start)
            for (uint i = pos; i < pos + removed; i++) {
                sorting.remove (i);
            }

            shift (pos, added - removed);

            for (uint i = pos; i < pos + added; i++) {
                sorting.add (i);
            }

            sorting.sort ((a, b) => {
                var notification_a = (Notification) store.get_item (a);
                var notification_b = (Notification) store.get_item (b);

                return notification_a.compare (notification_b);
            });

            items_changed (0, sorting.size - (added - removed), sorting.size);
        }

        notify_property ("n-notifications");
    }

    private void shift (uint from, uint by) {
        var iter = sorting.list_iterator ();
        while (iter.next ()) {
            var current_pos = iter.get ();
            if (current_pos >= from) {
                iter.set (current_pos + by);
            }
        }
    }

    public Object? get_item (uint pos) {
        return store.get_item (sorting[(int) pos]);
    }

    public uint get_n_items () {
        return n_notifications;
    }

    public Type get_item_type () {
        return typeof (Notification);
    }
}
