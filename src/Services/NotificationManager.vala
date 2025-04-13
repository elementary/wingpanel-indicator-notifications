/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Notifications.NotificationManager : Object {
    public const uint REMOVAL_ANIMATION = 300;

    [DBus (name = "io.elementary.portal.NotificationProvider")]
    private interface Provider : Object {
        public signal void items_changed (uint pos, uint removed, uint added);

        public abstract async uint get_n_items () throws DBusError, IOError;
        public abstract async Notification.Data get_notification (uint pos) throws DBusError, IOError;
    }

    public ListModel notifications { get; construct; }
    public ActionGroup action_group { get; construct; }

    private ListStore store;

    private Provider? provider;

    construct {
        store = new ListStore (typeof (Notification));

        var time_sorter = new Gtk.CustomSorter ((a, b) => {
            var notification_a = (Notification) a;
            var notification_b = (Notification) b;

            return notification_a.compare_time (notification_b);
        });

        var section_sorter = new Gtk.CustomSorter ((a, b) => {
            var notification_a = (Notification) a;
            var notification_b = (Notification) b;

            return notification_a.compare_section (notification_b);
        });

        notifications = new Gtk.SortListModel (store, time_sorter) {
            section_sorter = section_sorter
        };

        action_group = DBusActionGroup.get (
            Application.get_default ().get_dbus_connection (),
            "org.freedesktop.impl.portal.desktop.pantheon",
            "/io/elementary/portal/NotificationProvider"
        );

        connect_to_provider.begin ();
    }

    private async void connect_to_provider () {
        try {
            provider = yield Bus.get_proxy<Provider> (SESSION, "org.freedesktop.impl.portal.desktop.pantheon", "/io/elementary/portal/NotificationProvider");
            yield on_items_changed (0, 0, yield provider.get_n_items ());
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
}
