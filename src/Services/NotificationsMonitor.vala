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
    public signal void notification_closed (uint32 id, Notification.CloseReason reason);

    // matches method calls and signal emissions in the org.freedesktop.Notifications interface at /org/freedesktop/Notifications.
    private const string CALL_MATCH = "interface='org.freedesktop.Notifications',path='/org/freedesktop/Notifications'";
    // matches responses sent from the org.freedesktop.Notifications name.
    private const string RESPONSE_MATCH = "type=method_return,sender='org.freedesktop.Notifications'";
    // matches errors sent from the org.freeedesktop.Notifications name.
    private const string ERROR_MATCH = "type=error,sender='org.freedesktop.Notifications'";

    private Gee.Map<uint32, DBusMessage> awaiting = new Gee.HashMap<uint32, DBusMessage> ();
    private DBusConnection connection;

    public DBusActionGroup? notifications_action_group { get; private set; }

    construct {
        notifications_action_group = DBusActionGroup.get (
            Application.get_default ().get_dbus_connection (),
            NOTIFY_BUS_NAME,
            NOTIFY_PATH
        );

        initialize.begin ();
    }

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

        connection.add_filter (filter);
    }

    private DBusMessage? filter (DBusConnection connection, owned DBusMessage message, bool incoming) {
        if (!incoming) {
            return null;
        }

        var body = message.get_body ();
        debug (
            "got message (" +
            @"$(message.get_message_type ()), " +
            @"$(message.get_interface () ?? "null"), " +
            @"$(message.get_member () ?? "null"), " +
            @"$(body != null ? body.print (true) : "null"))"
        );

        switch (message.get_member ()) {
            case "Notify":
                try {
                    awaiting[message.get_serial ()] = message.copy ();
                } catch {
                    warning ("failed to make a copy of notify message, notification won't be included in the list");
                }

                break;

            case "CloseNotification":
            case "NotificationClosed":
            case "ActionInvoked":
                Notification.CloseReason reason;
                uint32 id = body.get_child_value (0).get_uint32 ();

                if (message.get_member () == "NotificationClosed") {
                    reason = body.get_child_value (1).get_uint32 ();
                } else if (message.get_member () == "ActionInvoked") {
                    reason = UNDEFINED;
                } else {
                    reason = CLOSE_NOTIFICATION_CALL;
                }

                emit_closed (id, reason);
                break;

            case null: // if null it's either a method_return or a error.
                DBusMessage awaiting_message;

                if (awaiting.unset (message.get_reply_serial (), out awaiting_message)) {
                    if (message.get_message_type () != METHOD_RETURN) {
                        break;
                    }

                    var hints = new VariantDict (awaiting_message.get_body ().get_child_value (6));
                    var id = body.get_child_value (0).get_uint32 ();

                    emit_closed (id, UNDEFINED); // make sure we remove a replaced notification.
                    bool transient;

                    if (hints.lookup ("transient", "b", out transient) && transient
                    || "x-canonical-private-synchronous" in hints
                    ) {
                        break; // don't append transient notifications.
                    }

                    // XXX: are this list still needed? or even right?
                    const string[] EXCEPTIONS = { "NetworkManager", "gnome-settings-daemon", "gnome-power-panel" };
                    var app_name = awaiting_message.get_body ().get_child_value (0).get_string ();
                    if (app_name in EXCEPTIONS) {
                        break;
                    }

                    emit_received (awaiting_message, id);
                }

                break;
        }

        return null;
    }

    private inline void emit_closed (uint32 id, Notification.CloseReason reason) {
        // HIGH_IDLE so that they got executed before gtk's resize/redrawing sources.
        GLib.MainContext.default ().invoke_full (GLib.Priority.HIGH_IDLE, () => {
            notification_closed (id, reason);
            return GLib.Source.REMOVE;
        });
    }

    private inline void emit_received (DBusMessage message, uint32 id) {
        // HIGH_IDLE + 1 so closed emissions run first.
        GLib.MainContext.default ().invoke_full (GLib.Priority.HIGH_IDLE + 1, () => {
            notification_received (message, id);
            return GLib.Source.REMOVE;
        });
    }
}
