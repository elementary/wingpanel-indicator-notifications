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

public class Notifications.Notification : Object {
    public const string DESKTOP_ID_EXT = ".desktop";

    public bool data_session;

    public string app_name;
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
    public GLib.DateTime timestamp;
    public int64 unix_time;

    public string desktop_id {
        get {
            if (app_info != null) {
                return app_info.get_id ();
            }

            return "";
        }   
    }

    public AppInfo? app_info = null;

    public signal void closed ();
    public signal bool time_changed (GLib.DateTime span);

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
    private const string X_CANONICAL_PRIVATE_KEY = "x-canonical-private-synchronous";
    private const string DESKTOP_ENTRY_KEY = "desktop-entry";
    private const string FALLBACK_DESKTOP_ID = "gala-other" + DESKTOP_ID_EXT;

    private static DesktopAppInfo? fallback_info;

    static construct {
        fallback_info = new DesktopAppInfo (FALLBACK_DESKTOP_ID);
    }

    public Notification.from_message (DBusMessage message, uint32 _id) {
        var body = message.get_body ();

        data_session = false;

        app_name = get_string (body, Column.APP_NAME);
        app_icon = get_string (body, Column.APP_ICON);
        summary = get_string (body, Column.SUMMARY);
        message_body = get_string (body, Column.BODY);
        hints = body.get_child_value (Column.HINTS);
        expire_timeout = get_int32 (body, Column.EXPIRE_TIMEOUT);
        replaces_id = get_uint32 (body, Column.REPLACES_ID);
        id = _id;
        sender = message.get_sender ();

        actions = body.get_child_value (Column.ACTIONS).dup_strv ();
        timestamp = new GLib.DateTime.now_local ();
        unix_time = timestamp.to_unix ();

        setup_pid ();

        string? _desktop_id = lookup_string (hints, DESKTOP_ENTRY_KEY);
        if (_desktop_id != null && _desktop_id != "") {
            if (!_desktop_id.has_suffix (DESKTOP_ID_EXT)) {
                _desktop_id += DESKTOP_ID_EXT;        
            }
            
            app_info = new DesktopAppInfo (_desktop_id);
        } else {
            app_info = get_appinfo ();
        }

        Timeout.add_seconds_full (Priority.DEFAULT, 60, source_func);
    }

    public Notification.from_data (uint32 _id, string _app_name, string _app_icon,
                                string _summary, string _message_body,
                                string[] _actions, string _desktop_id, int64 _unix_time, string _sender) {
        data_session = true;

        app_name = _app_name;
        app_icon = _app_icon;
        summary = _summary;
        message_body = _message_body;
        expire_timeout = -1;
        replaces_id = 0;
        id = _id;
        sender = _sender;

        actions = _actions;
        unix_time = _unix_time;
        timestamp = new GLib.DateTime.from_unix_local (unix_time);

        setup_pid ();

        app_info = new DesktopAppInfo (_desktop_id);

        Timeout.add_seconds_full (Priority.DEFAULT, 60, source_func);
    }

    public bool get_is_valid () {
        var transient = hints.lookup_value("transient", VariantType.BOOLEAN);
        return app_info != null && hints.lookup_value (X_CANONICAL_PRIVATE_KEY, null) == null && (transient == null || !transient.get_boolean ());
    }

    public void close () {
        closed ();
    }

    public bool run_default_action () {
        if (DEFAULT_ACTION in actions && NotificationMonitor.get_instance ().notifications_iface != null) {
            NotificationMonitor.get_instance ().notifications_iface.action_invoked (DEFAULT_ACTION, id);
            return true;
        }

        return false;
    }

    public Wnck.Window? get_app_window () {
        Wnck.Window? window = null;
        Wnck.Screen.get_default ().get_windows ().foreach ((_window) => {
            if (_window.get_pid () == pid && window == null) {
                window = _window;
                return;
            }
        });

        return window;        
    }

    private AppInfo get_appinfo () {
        var matcher = Bamf.Matcher.get_default ();

        Bamf.Application? app = null;

        List<weak Bamf.Application> apps = matcher.get_applications ();
        for (int i = 0; i < apps.length (); i++) {
            weak Bamf.Application _app = apps.nth_data (i);
            if (get_application_owns_pid (_app, pid)) {
                app = _app;
                break;
            }
        }

        if (app == null) {
            return fallback_info;
        }

        var desktop_app = new DesktopAppInfo.from_filename (app.get_desktop_file ());
        if (desktop_app == null) {
            return fallback_info;
        }

        return desktop_app;
    }

    private static bool get_application_owns_pid (Bamf.Application app, uint32 pid) {
        List<weak Bamf.Window> windows = app.get_windows ();
        for (int i = 0; i < windows.length (); i++) {
            weak Bamf.Window win = windows.nth_data (i);
            if (win.get_pid () == pid) {
                return true;
            }
        }

        return false;
    }

    private void setup_pid () {
        try {
            IDBus? dbus_iface = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.DBus", "/");
            if (dbus_iface != null && dbus_iface.name_has_owner (sender)) {
                pid = dbus_iface.get_connection_unix_process_id (sender);
            }
        } catch (Error e) {
            warning ("%s\n", e.message);
        }
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
        return time_changed (timestamp);
    }
}
