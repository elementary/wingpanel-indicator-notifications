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

public class Notification : Object {
    public bool data_session;

    public string app_name;
    public string display_name;
    public string summary;
    public string message_body;
    public string app_icon;
    public string sender;
    public string[] actions;
    public int32 expire_timeout;
    public uint32 replaces_id;

    /* We cannot convert uint64 to uint32 and
     * we need to store them in the separate
     * variables.
     */
    public uint id;
    public uint64 id_64;
    public uint32 pid = 0;
    public DateTime timestamp;
    public int64 unix_time;

    public signal bool time_changed (TimeSpan span);

    private enum Column {
        APP_NAME = 0,
        REPLACES_ID,
        APP_ICON,
        SUMMARY,
        BODY,
        ACTIONS,
        HINTS,
        EXPIRE_TIMEOUT,
        COUNT
    }

    private const string DEFAULT = "default";
    private bool pid_accuired;

    public Notification.from_message (DBus.RawMessage message, uint32 _id) {
        void* _app_name, _replaces_id, _app_icon, _summary, _body, _actions, _hints, _expire_timeout;

        DBus.RawMessageIter iter;
        message.iter_init (out iter);

        this.data_session = false;

        iter.get_basic (out _app_name);
        iter.next ();

        iter.get_basic (out _replaces_id);
        iter.next ();

        iter.get_basic (out _app_icon);
        iter.next ();

        iter.get_basic (out _summary);
        iter.next ();

        iter.get_basic (out _body);
        iter.next ();

        iter.get_basic (out _actions);
        iter.next ();
        iter.next ();

        iter.get_basic (out _expire_timeout);

        this.app_name = (string) _app_name;
        this.display_name = app_name;
        this.replaces_id = (uint) _replaces_id;
        this.app_icon = (string) _app_icon;
        this.summary = (string) _summary;
        this.message_body = (string) _body;
        this.actions = (string[]) actions;
        this.expire_timeout = (int) expire_timeout;
        this.id = _id;
        this.id_64 = -1;
        this.sender = message.get_sender ();

        setup_pid ();

        this.timestamp = new DateTime.now_local ();
        this.unix_time = timestamp.to_unix ();

        Timeout.add_seconds_full (Priority.DEFAULT, 60, source_func);
    }

    public Notification.from_data (uint64 _id, string _app_name, string _app_icon,
                                string _summary, string _message_body,
                                string[] _actions, int64 _unix_time, string _sender) {
        this.data_session = true;

        this.app_name = _app_name;
        this.display_name = app_name;
        this.app_icon = _app_icon;
        this.summary = _summary;
        this.message_body = _message_body;
        this.expire_timeout = -1;
        this.replaces_id = 0;
        this.id = (uint32) _id;
        this.sender = _sender;

        setup_pid ();

        this.actions = _actions;
        this.unix_time = _unix_time;
        this.timestamp = new DateTime.from_unix_local (unix_time);

        Timeout.add_seconds_full (Priority.DEFAULT, 60, source_func);
    }

    private void setup_pid () {
        this.pid_accuired = this.try_get_pid ();
        nsettings.changed["do-not-disturb"].connect (() => {
            if (!pid_accuired) {
                this.try_get_pid ();
            }
        });
    }

    private bool try_get_pid () {
        if (nsettings.do_not_disturb) {
            return false;
        }

        try {
            DBusIface? dbusiface = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.DBus", "/");
            if (dbusiface.name_has_owner (sender)) {
                this.pid = dbusiface.get_connection_unix_process_id (sender);
            }

        } catch (Error e) {
            error ("%s\n", e.message);
        }

        return true;
    }

    public bool run_default_action () {
        if (DEFAULT in actions) {
            monitor.niface.action_invoked (DEFAULT, id);
            return true;
        }

        return false;
    }

    private bool source_func () {
        return this.time_changed (timestamp.difference (new DateTime.now_local ()));
    }
}
