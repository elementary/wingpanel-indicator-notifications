/*-
 * Copyright 2015-2020 elementary, Inc. (https://elementary.io)
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
    public signal void closed ();
    public signal bool time_changed (GLib.DateTime span);

    public const string DESKTOP_ID_EXT = ".desktop";

    public GLib.DateTime timestamp { get; construct; }
    public string[] actions { get; construct; }
    public string app_icon { get; construct; }
    public string app_name { get; construct; }
    public string desktop_id { get; construct; }
    public string message_body { get; construct; }
    public string sender { get; construct; }
    public string summary { get; construct; }
    public uint32 id { get; construct; }
    public uint32 replaces_id { get; construct; }

    public DesktopAppInfo? app_info { get; private set; default = null; }

    private Variant hints;

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

    public Notification.from_message (DBusMessage message, uint32 id) {
        var body = message.get_body ();
        var hints = body.get_child_value (Column.HINTS);

        Object (
            actions: body.get_child_value (Column.ACTIONS).dup_strv (),
            app_icon: get_string (body, Column.APP_ICON),
            app_name: get_string (body, Column.APP_NAME),
            desktop_id: lookup_string (hints, DESKTOP_ENTRY_KEY),
            id: id,
            message_body: get_string (body, Column.BODY),
            replaces_id: get_uint32 (body, Column.REPLACES_ID),
            sender: message.get_sender (),
            summary: get_string (body, Column.SUMMARY),
            timestamp: new GLib.DateTime.now_local ()
        );
    }

    public Notification.from_data (
        uint32 id, string app_name, string app_icon,
        string summary, string message_body, string[] actions,
        string desktop_id, int64 unix_time, uint64 replaces_id, string sender
    ) {
        Object (
            actions: actions,
            app_icon: app_icon,
            app_name: app_name,
            desktop_id: desktop_id,
            id: id,
            message_body: message_body,
            replaces_id: (uint32) replaces_id,
            sender: sender,
            summary: summary,
            timestamp: new GLib.DateTime.from_unix_local (unix_time)
        );
    }

    construct {
        if (desktop_id != "") {
            // Avoid example.desktop.desktop
            desktop_id.replace (".desktop", "");
            desktop_id += DESKTOP_ID_EXT;
        } else {
            desktop_id = FALLBACK_DESKTOP_ID;
        }

        app_info = new DesktopAppInfo (desktop_id);

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
