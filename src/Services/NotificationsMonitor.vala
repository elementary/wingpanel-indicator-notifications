/*
 * Copyright 2015 Wingpanel Developers (http://launchpad.net/wingpanel)
 * Copyright 2015-2023 elementary, Inc (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

/*
 * Original code from:
 * http://bazaar.launchpad.net/~jconti/recent-notifications/gnome3/view/head:/src/recent-notifications.vala
 */
[SingleInstance]
public sealed class Notifications.NotificationsMonitor : Object {
    public signal void notification_received (DBusMessage message, uint32 id);
    public signal void notification_closed (uint32 id, uint32 reason);

    // matches method calls and signal emissions in the org.freedesktop.Notifications interface at /org/freedesktop/Notifications.
    private const string CALL_MATCH = "interface='org.freedesktop.Notifications',path='/org/freedesktop/Notifications'";
    // matches responses sent from the org.freedesktop.Notifications name.
    private const string RESPONSE_MATCH = "type=method_return,sender='org.freedesktop.Notifications'";
    // matches errors sent from the org.freeedesktop.Notifications name.
    private const string ERROR_MATCH = "type=error,sender='org.freedesktop.Notifications'";

    private DBusConnection connection;
    private DBusMessage? awaiting_reply = null;

    public async void init () throws Error {
#if VALA_0_54
        string address = BusType.SESSION.get_address_sync ();
#else
        string address = BusType.get_address_sync (BusType.SESSION);
#endif
        connection = yield new DBusConnection.for_address (address, AUTHENTICATION_CLIENT | MESSAGE_BUS_CONNECTION);

        yield connection.call (
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus.Monitoring",
            "BecomeMonitor",
            new Variant.tuple ({
                new Variant.array (VariantType.STRING, { CALL_MATCH, RESPONSE_MATCH, ERROR_MATCH }),
                0U
            }),
            null,
            NONE,
            -1
        );

        connection.add_filter (message_filter);
    }

    private DBusMessage? message_filter (DBusConnection con, owned DBusMessage message, bool incoming) {
        if (incoming) {
            switch (message.get_message_type ()) {
                case DBusMessageType.METHOD_CALL:
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
                            notification_closed (id, Notification.CloseReason.CLOSE_NOTIFICATION_CALL);
                            return Source.REMOVE;
                        });
                    }

                    break;

                case DBusMessageType.SIGNAL:
                    if (message.get_member () == "NotificationClosed") {
                        unowned GLib.Variant? body = message.get_body ();
                        if (body == null || body.n_children () != 2) {
                            return message;
                        }

                        var id_val = body.get_child_value (0);
                        if (!id_val.is_of_type (VariantType.UINT32)) {
                            return message;
                        }

                        var reason_val = body.get_child_value (1);
                        if (!reason_val.is_of_type (VariantType.UINT32)) {
                            return message;
                        }

                        uint32 id = id_val.get_uint32 ();
                        uint32 reason = reason_val.get_uint32 ().clamp (1, 4);
                        Idle.add (() => {
                            notification_closed (id, reason);
                            return Source.REMOVE;
                        });
                    }

                    break;

                default:
                    break;
            }

            return null;
        } else if (awaiting_reply != null && awaiting_reply.get_serial () == message.get_reply_serial ()) {
            switch (message.get_message_type ()) {
                case DBusMessageType.METHOD_RETURN:
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
                            return Source.REMOVE;
                        });
                    } catch (Error e) {
                        warning (e.message);
                    }

                    awaiting_reply = null;
                    break;

                case DBusMessageType.ERROR:
                    awaiting_reply = null;
                    break;
                default:
                    break;
            }
        }

        return message;
    }
}
