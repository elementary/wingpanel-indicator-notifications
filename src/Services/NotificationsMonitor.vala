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
    private const string MATCH_RULE = "eavesdrop=true,type='method_call',interface='org.freedesktop.Notifications',member='Notify'";
    private const uint32 REASON_DISMISSED = 2;

    private DBusConnection connection;
    public NIface? niface = null;
    public DBusIface? dbusiface = null;
    private uint32 id_counter = 0;

    public signal void received (Notification notification);

    public NotificationMonitor () {
        try {
            connection = Bus.get_sync (BusType.SESSION);
        } catch (Error e) {
            error ("%s\n", e.message);
        }

        this.add_filter ();
    }

    private void add_filter () {
        try {
            niface = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.Notifications",
                                                      "/org/freedesktop/Notifications"); 
        } catch (Error e) {
            error ("%s\n", e.message);
        }

        id_counter = get_current_notification_id ();

        var filter_connection = DBus.Bus.@get (DBus.BusType.SESSION);
        var raw_connection = filter_connection.get_connection ();
        var error = DBus.RawError ();
        raw_connection.add_match (MATCH_RULE, ref error);
        raw_connection.add_filter (message_filter);
    }

    private DBus.RawHandlerResult message_filter (DBus.RawConnection connection, DBus.RawMessage message) {
        if (message.get_sender () != "org.freedesktop.DBus") {
            var notification = new Notification.from_message (message, id_counter);
            uint replaces_id = notification.replaces_id;
            uint current_id = replaces_id;

            if (replaces_id == 0) {
                id_counter++;
                current_id = id_counter;
            }

            if (nsettings.do_not_disturb) {
                this.received (notification);
            } else {
                niface.notification_closed.connect ((id, reason) => {
                    if (id == 1) {
                        id_counter = id;
                        current_id = id_counter;
                    }

                    if (reason != REASON_DISMISSED && current_id == id) {
                        this.received (notification);                
                    }                      
                });                 
            }
        }

        return DBus.RawHandlerResult.HANDLED;
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