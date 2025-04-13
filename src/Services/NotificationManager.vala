/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Notifications.NotificationManager : Object {
    [DBus (name = "io.elementary.portal.NotificationProvider")]
    private interface Provider : Object {
        public signal void items_changed (uint pos, uint removed, uint added);

        public abstract async uint get_n_items () throws DBusError, IOError;
        public abstract async Notification.Data get_notification (uint pos) throws DBusError, IOError;
    }

    public ListStore notifications { get; construct; }
    public ActionGroup action_group { get; construct; }

    private Provider? provider;

    construct {
        notifications = new ListStore (typeof (Notification));

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

    private async void on_items_changed (uint pos, uint removed, uint added) {
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

        // Add a delay if only removed to allow collapse animation to finish
        notifications.splice (pos, removed, added_notification);
    }
}
