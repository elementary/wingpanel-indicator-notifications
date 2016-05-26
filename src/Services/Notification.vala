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
    public Variant hints;
    public int32 expire_timeout;
    public uint32 replaces_id;
    public uint32 id;
    public uint32 pid = 0;
    public DateTime timestamp;
    public int64 unix_time;

    public string desktop_id;
    public AppInfo? appinfo = null;

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

    private const string DEFAULT_ACTION = "default";
    private const string DESKTOP_ENTRY_KEY = "desktop-entry";
    private const string DESKTOP_ID_EXT = ".desktop";
    private const string[] OTHER_WHITELIST = { "notify-send" };
    private bool pid_accuired;

    public Notification.from_message (DBusMessage message, uint32 _id) {
        var body = message.get_body ();

        this.data_session = false;

        this.app_name = this.get_string (body, Column.APP_NAME);
        this.display_name = app_name;
        this.app_icon = this.get_string (body, Column.APP_ICON);
        this.summary = this.get_string (body, Column.SUMMARY);
        this.message_body = this.get_string (body, Column.BODY);
        this.hints = body.get_child_value (Column.HINTS);
        this.expire_timeout = this.get_int32 (body, Column.EXPIRE_TIMEOUT);
        this.replaces_id = this.get_uint32 (body, Column.REPLACES_ID);
        this.id = _id;
        this.sender = message.get_sender ();

        this.actions = body.get_child_value (Column.ACTIONS).dup_strv ();
        this.timestamp = new DateTime.now_local ();
        this.unix_time = timestamp.to_unix ();

        this.desktop_id = lookup_string (this.hints, DESKTOP_ENTRY_KEY);
        if (desktop_id != "" && !desktop_id.has_suffix (DESKTOP_ID_EXT)) {
            this.desktop_id += DESKTOP_ID_EXT;
        }

        appinfo = Utils.get_appinfo_from_app_name (app_name);
        if (desktop_id != "" && appinfo == null) {
            appinfo = new DesktopAppInfo (desktop_id);
        }

        set_properties ();
        setup_pid ();

        Timeout.add_seconds_full (Priority.DEFAULT, 60, source_func);
    }

    public Notification.from_data (uint32 _id, string _app_name, string _app_icon,
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
        this.id = _id;
        this.sender = _sender;

        set_properties ();
        setup_pid ();

        this.actions = _actions;
        this.unix_time = _unix_time;
        this.timestamp = new DateTime.from_unix_local (unix_time);

        this.desktop_id = "";

        Timeout.add_seconds_full (Priority.DEFAULT, 60, source_func);
    }

    public bool get_is_valid () {
        return app_name in OTHER_WHITELIST || appinfo != null;
    }

    private void set_properties () {
        if (app_name in OTHER_WHITELIST) {
            this.display_name = _("Other");
            this.app_icon = "dialog-information";            
        }
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
        if (DEFAULT_ACTION in actions) {
            monitor.niface.action_invoked (DEFAULT_ACTION, id);
            return true;
        }

        return false;
    }

    private string get_string (Variant tuple, int column) {
        var child = tuple.get_child_value (column);
        return child.dup_string ();
    }

    private int32 get_int32 (Variant tuple, int column) {
        var child = tuple.get_child_value (column);
        return child.get_int32 ();
    }

    private uint32 get_uint32 (Variant tuple, int column) {
        var child = tuple.get_child_value (column);
        return child.get_uint32 ();
    }

    private string lookup_string (Variant tuple, string key) {
        var child = tuple.lookup_value (key, null);

        if (child == null || !child.is_of_type (VariantType.STRING)) {
            return "";
        }

        return child.dup_string ();
    }

    private bool source_func () {
        return this.time_changed (timestamp.difference (new DateTime.now_local ()));
    }
}
