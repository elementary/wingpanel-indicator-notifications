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
    public GLib.DateTime timestamp;

    public string desktop_id;
    public DesktopAppInfo? app_info = null;

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

    public Notification.from_message (DBusMessage message, uint32 _id) {
        var body = message.get_body ();

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

        desktop_id = lookup_string (hints, DESKTOP_ENTRY_KEY);
        if (desktop_id != "" && !desktop_id.has_suffix (DESKTOP_ID_EXT)) {
            desktop_id += DESKTOP_ID_EXT;

            app_info = new DesktopAppInfo (desktop_id);
        }

        if (app_info == null) {
            desktop_id = FALLBACK_DESKTOP_ID;
            app_info = new DesktopAppInfo (desktop_id);
        }
    }

    public Notification.from_data (uint32 _id, string _app_name, string _app_icon,
                                string _summary, string _message_body,
                                string[] _actions, string _desktop_id, int64 _unix_time, string _sender) {

        app_name = _app_name;
        app_icon = _app_icon;
        summary = _summary;
        message_body = _message_body;
        expire_timeout = -1;
        replaces_id = 0;
        id = _id;
        sender = _sender;

        actions = _actions;
        timestamp = new GLib.DateTime.from_unix_local (_unix_time);

        desktop_id = _desktop_id;
        app_info = new DesktopAppInfo (desktop_id);
    }

    construct {
        Timeout.add_seconds_full (Priority.DEFAULT, 60, source_func);
    }

    public bool get_is_valid () {
        var transient = hints.lookup_value ("transient", VariantType.BOOLEAN);
        return app_info != null && hints.lookup_value (X_CANONICAL_PRIVATE_KEY, null) == null && (transient == null || !transient.get_boolean ());
    }

    public void close () {
        closed ();
    }

    public bool run_default_action () {
        if (DEFAULT_ACTION in actions) {
            app_info.launch_action (DEFAULT_ACTION, new GLib.AppLaunchContext ());

            var notifications_iface = NotificationMonitor.get_instance ().notifications_iface;
            if (notifications_iface != null) {
                notifications_iface.action_invoked (id, DEFAULT_ACTION);
            }

            return true;
        } else {
            try {
                app_info.launch (null, null);
            } catch (Error e) {
                critical ("Unable to launch app: %s", e.message);
            }
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
        return time_changed (timestamp);
    }
}
