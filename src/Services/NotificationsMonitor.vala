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

/*
 * Original code from:
 * http://bazaar.launchpad.net/~jconti/recent-notifications/gnome3/view/head:/src/recent-notifications.vala
 */

public class Notifications.NotificationMonitor : Object {
    private const string NOTIFY_IFACE = "org.freedesktop.Notifications";
    private const string NOTIFY_PATH = "/org/freedesktop/Notifications";
    private const string METHOD_CALL_MATCH_STRING = "type='method_call',interface='org.freedesktop.Notifications'";
    private const string METHOD_RETURN_MATCH_STRING = "type='method_return'";
    private const string ERROR_MATCH_STRING = "type='error'";
    private const uint32 REASON_DISMISSED = 2;

    private static NotificationMonitor? instance = null;

    private DBusConnection connection;
    private DBusMessage? awaiting_reply = null;

    public signal void notification_received (DBusMessage message, uint32 id);
    public signal void notification_closed (uint32 id);

    public static NotificationMonitor get_instance () {
        if (instance == null) {
            instance = new NotificationMonitor ();
        }

        return instance;
    }

    public INotifications? notifications_iface = null;

    private NotificationMonitor () {
        try {
            // Set up a private connection to the session bus
#if VALA_0_54
            string address = BusType.SESSION.get_address_sync ();
#else
            string address = BusType.get_address_sync (BusType.SESSION);
#endif
            connection = new DBusConnection.for_address_sync (
                address,
                DBusConnectionFlags.AUTHENTICATION_CLIENT | DBusConnectionFlags.MESSAGE_BUS_CONNECTION
            );
            connection.add_filter (message_filter);

            connection.call_sync (
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus.Monitoring",
                "BecomeMonitor",
                new Variant.tuple ({
                    new Variant.array (VariantType.STRING, {
                        METHOD_CALL_MATCH_STRING,
                        METHOD_RETURN_MATCH_STRING,
                        ERROR_MATCH_STRING
                    }),
                    (uint32)0
                }),
                null,
                DBusCallFlags.NONE,
                -1
            );
        } catch (Error e) {
            critical ("Unable to monitor notifications bus: %s", e.message);
        }

        try {
            notifications_iface = Bus.get_proxy_sync (BusType.SESSION, NOTIFY_IFACE, NOTIFY_PATH);
        } catch (Error e) {
            warning ("Unable to connection to notifications bus: %s", e.message);
        }
    }

    private DBusMessage? message_filter (DBusConnection con, owned DBusMessage message, bool incoming) {
        if (incoming && message.get_interface () == NOTIFY_IFACE && message.get_message_type () == DBusMessageType.METHOD_CALL) {
            if (message.get_member () == "Notify") {
                try {
                    awaiting_reply = message.copy ();
                } catch (Error e) {
                    warning (e.message);
                }
            } else if (message.get_member () == "CloseNotification") {
                unowned GLib.Variant? body = message.get_body ();
                if (body == null || body.n_children () != 1) {
                    return message;
                }

                var child = body.get_child_value (0);
                if (!child.is_of_type (VariantType.UINT32)) {
                    return message;
                }

                uint32 id = child.get_uint32 ();
                Idle.add (() => {
                    notification_closed (id);
                    return false;
                });
            }

            return null;
        } else if (awaiting_reply != null && awaiting_reply.get_serial () == message.get_reply_serial ()) {
            if (message.get_message_type () == DBusMessageType.METHOD_RETURN) {
                unowned GLib.Variant? body = message.get_body ();
                if (body == null || body.n_children () != 1) {
                    return message;
                }

                var child = body.get_child_value (0);
                if (!child.is_of_type (VariantType.UINT32)) {
                    return message;
                }

                uint32 id = child.get_uint32 ();
                try {
                    var copy = awaiting_reply.copy ();
                    Idle.add (() => {
                        notification_received (copy, id);
                        return false;
                    });
                } catch (Error e) {
                    warning (e.message);
                }

                awaiting_reply = null;
            } else if (message.get_message_type () == DBusMessageType.ERROR) {
                awaiting_reply = null;
            }
        }

        return message;
    }
}
