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
}

public class NotificationMonitor : Object {
    private const string MATCH_STRING = "eavesdrop=true,type='method_call',interface='org.freedesktop.Notifications',member='Notify'";
    private const uint32 REASON_DISMISSED = 2;
    private DBusConnection connection;
    private NIface? niface = null;
    public signal void received (DBusMessage message);

    public NotificationMonitor () {
        try {
            connection = Bus.get_sync (BusType.SESSION);
        } catch (Error e) {
            error ("%s\n", e.message);
        }

        this.add_filter ();  
    }

    private void add_filter () {
        var message = new DBusMessage.method_call ("org.freedesktop.DBus",
                                                "/org/freedesktop/DBus",
                                                "org.freedesktop.DBus",
                                                "AddMatch");

        var body = new Variant.parsed ("(%s,)", MATCH_STRING);
        message.set_body (body);
        
        try {
            niface = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.Notifications",
                                                      "/org/freedesktop/Notifications"); 
        } catch (Error e) {
            error ("%s\n", e.message);
        }

        connection.send_message_with_reply (message, DBusSendMessageFlags.NONE, -1);
        connection.add_filter (filter_function);
    }

    private DBusMessage filter_function (DBusConnection con, owned DBusMessage message, bool incoming) {
        if (incoming) {
            if ((message.get_message_type () == DBusMessageType.METHOD_CALL) &&
                (message.get_interface () == "org.freedesktop.Notifications") &&
                (message.get_member () == "Notify")) {  
                    niface.notification_closed.connect ((id, reason) => {
                        if (reason != REASON_DISMISSED)
                            this.received (message);
                            message = null;                          
                    });
            }
        }

        return message;
    }  
}