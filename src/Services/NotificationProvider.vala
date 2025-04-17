/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

[SingleInstance]
public class Notifications.NotificationProvider : Object {
    [DBus (name = "io.elementary.portal.NotificationProvider")]
    private interface Provider : Object {
        public signal void items_changed (uint pos, uint removed, uint added);

        public abstract async uint get_n_items () throws DBusError, IOError;
        public abstract async Notification.Data get_notification (uint pos) throws DBusError, IOError;
    }

    public const uint REMOVAL_ANIMATION = 300;

    public ActionGroup action_group { get; construct; }
    public ListModel notifications { get { return store; } }

    private ListStore store;

    private Provider? provider;

    construct {
        action_group = DBusActionGroup.get (
            Application.get_default ().get_dbus_connection (),
            "org.freedesktop.impl.portal.desktop.pantheon",
            "/io/elementary/portal/NotificationProvider"
        );

        store = new ListStore (typeof (Notification));

        Bus.watch_name (SESSION, "org.freedesktop.impl.portal.desktop.pantheon", NONE, () => connect_to_provider.begin (), () => {
            provider = null;
            store.remove_all ();
        });
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

    private async void on_items_changed (uint pos, uint removed, uint added) {
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
}
