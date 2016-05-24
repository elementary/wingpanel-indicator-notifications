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

[DBus (name = "org.freedesktop.Notifications")]
public interface NIface : Object {
    public signal void notification_closed (uint32 id, uint32 reason);
    public signal void action_invoked (string action, uint32 id);
    public abstract uint32 notify (string app_name,
                                uint32 replaces_id,
                                string app_icon,
                                string summary,
                                string body,
                                string[] actions,
                                HashTable<string, Variant> hints,
                                int32 expire_timeout) throws Error;
}

[DBus (name = "org.freedesktop.DBus")]
public interface DBusIface : Object {
    [DBus (name = "NameHasOwner")]
    public abstract bool name_has_owner (string name) throws Error;

    [DBus (name = "GetConnectionUnixProcessID")]
    public abstract uint32 get_connection_unix_process_id (string name) throws Error;
}

public class NotificationMonitor : Object {
    private const string NOTIFY_IFACE = "org.freedesktop.Notifications";
    private const string NOTIFY_PATH = "/org/freedesktop/Notifications";
    private const string MATCH_STRING = "eavesdrop='true',type='method_call',interface='org.freedesktop.Notifications',member='Notify'";
    private const uint32 REASON_DISMISSED = 2;

    private DBusConnection connection;
    public NIface? niface = null;
    public DBusIface? dbusiface = null;
    private uint32 id_counter = 0;

    public signal void received (DBusMessage message, uint32 id);

    public NotificationMonitor () {
        try {
            connection = Bus.get_sync (BusType.SESSION);
            this.add_filter ();  
        } catch (Error e) {
            error ("%s\n", e.message);
        }
    }

    private void add_filter () {
        var message = new DBusMessage.method_call ("org.freedesktop.DBus",
                                                "/org/freedesktop/DBus",
                                                "org.freedesktop.DBus",
                                                "AddMatch");

        var body = new Variant.parsed ("(%s,)", MATCH_STRING);
        message.set_body (body);
        
        try {
            niface = Bus.get_proxy_sync (BusType.SESSION, NOTIFY_IFACE, NOTIFY_PATH); 
        } catch (Error e) {
            error ("%s\n", e.message);
        }

        id_counter = get_current_notification_id ();
        try {
            connection.send_message (message, DBusSendMessageFlags.NONE, null);
        } catch (Error e) {
            error ("%s\n", e.message);
        }

        connection.add_filter (message_filter);
    }

    private DBusMessage message_filter (DBusConnection con, owned DBusMessage message, bool incoming) {
        if (incoming) {
            if ((message.get_message_type () == DBusMessageType.METHOD_CALL) &&
                (message.get_interface () == NOTIFY_IFACE) &&
                (message.get_member () == "Notify")) {
                uint32 replaces_id = message.get_body ().get_child_value (1).get_uint32 ();
                uint32 current_id = replaces_id; 

                if (replaces_id == 0) {
                    id_counter++;
                    current_id = id_counter;
                }

                if (nsettings.do_not_disturb) {
                    this.received (message, current_id);
                } else {
                    niface.notification_closed.connect ((id, reason) => {
                        if (id == 1) {
                            id_counter = id;
                            current_id = id_counter;
                        }

                        if (reason != REASON_DISMISSED && current_id == id) {
                            this.received (message, id);
                            message = null;
                        }
                    });
                }

                return null;

            }
        }

        return message;
    }

    /* Check what's the current notification id */
    private uint32 get_current_notification_id () {
        var hints = new HashTable<string, Variant> (str_hash, str_equal);
        hints.insert ("suppress-sound", new Variant.boolean (true));
        string[] actions = {};
        try {
            return niface.notify ("", 0, "", "", "", actions, hints, 1);
        } catch (Error e) {
            error ("%s\n", e.message);
        }
    } 
}
