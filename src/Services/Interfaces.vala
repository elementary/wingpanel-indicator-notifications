/*-
 * Copyright (c) 2016 Wingpanel Developers (http://launchpad.net/wingpanel)
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

[DBus (name = "org.freedesktop.Notifications")]
public interface Notifications.INotifications : Object {
    public signal void notification_closed (uint32 id, uint32 reason);
    public signal void action_invoked (uint32 id, string action);
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
public interface Notifications.IDBus : Object {
    [DBus (name = "NameHasOwner")]
    public abstract bool name_has_owner (string name) throws Error;

    [DBus (name = "GetConnectionUnixProcessID")]
    public abstract uint32 get_connection_unix_process_id (string name) throws Error;
}
