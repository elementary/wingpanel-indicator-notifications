/*
 * Original code from:
 * http://bazaar.launchpad.net/~jconti/recent-notifications/gnome3/view/head:/src/recent-notifications.vala
 */

using GLib;

public class NotificationMonitor : Object {
    private const string MATCH_STRING = "eavesdrop=true,type='method_call',interface='org.freedesktop.Notifications',member='Notify'";
    private DBusConnection connection = null;
    public signal void received (DBusMessage message);

    public NotificationMonitor () {
        Bus.get.begin (BusType.SESSION, null, (obj, res) => {
            try {
                this.connection = Bus.get.end (res);
            } catch (IOError e) {
                error("Failed to connect to session bus: %s\n", e.message);
            }

            this.add_filter ();
        });
    }

    private void add_filter () {
        var message = new DBusMessage.method_call ("org.freedesktop.DBus",
                                                "/org/freedesktop/DBus",
                                                "org.freedesktop.DBus",
                                                "AddMatch");

        var body = new Variant.parsed ("(%s,)", MATCH_STRING);

        message.set_body (body);

        try {
            this.connection.send_message (message, DBusSendMessageFlags.NONE, null);
        } catch (Error e) {
            error("Failed to add match string: %s", e.message);
        }

        this.connection.add_filter ((connection, message, incoming) => {
            if (incoming) {
                if ((message.get_message_type () == DBusMessageType.METHOD_CALL) &&
                    (message.get_interface() == "org.freedesktop.Notifications") &&
                    (message.get_member() == "Notify")) {
                        this.received (message);
                        message = null;
                }
            }

            return message;
        });
    }
}