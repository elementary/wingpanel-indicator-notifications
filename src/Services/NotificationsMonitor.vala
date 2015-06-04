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