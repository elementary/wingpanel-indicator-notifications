/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Notifications.Notification : Object {
    [Flags]
    public enum DisplayHint {
        TRANSIENT,
        TRAY,
        PERSISTENT,
        HIDE_ON_LOCK_SCREEN,
        HIDE_CONTENT_ON_LOCK_SCREEN,
        SHOW_AS_NEW
    }

    public struct Data {
        public int64 timestamp;
        public HashTable<string, Variant> raw_data;
        public string app_id;
        public string dismiss_action_name;
        public string default_action_name;
        public Variant default_action_target;
        public Button.Data[] buttons;
        public DisplayHint display_hint;
    }

    /**
     * Action targets for the action names provided by the notification and its buttons
     * should be (sv) variants where s is an XDG_ACTIVATION_TOKEN and v is the action_target
     * provided
     */
    public const string ACTION_TARGET_TYPE_STRING = "(sv)";

    private static HashTable<string, DateTime> latest_for_app_id = new HashTable<string, DateTime> (str_hash, str_equal);

    public string app_id { get; construct; }

    public string title { get; construct; }
    public string body { get; construct; }

    public Icon primary_icon { get; construct; }

    public DateTime timestamp { get; construct; }

    public string dismiss_action_name { get; construct; }
    public string default_action_name { get; construct; }
    public Variant default_action_target { get; construct; }
    public ListStore buttons { get; construct; }

    public DisplayHint display_hint { get; construct; }

    // "Private" properties used for display purposes only
    public bool collapsed { get; set; default = false; }

    public Notification (Data data) {
        string title;
        if ("title" in data.raw_data) {
            title = data.raw_data["title"].get_string ();
        } else {
            title = "";
        }

        string body;
        if ("body" in data.raw_data) {
            body = data.raw_data["body"].get_string ();
        } else {
            body = "";
        }

        var primary_icon = new ThemedIcon (data.app_id);

        var buttons = new ListStore (typeof (Button));

        foreach (var button_data in data.buttons) {
            buttons.append (new Button (button_data));
        }

        Object (
            app_id: data.app_id,
            title: title,
            body: body,
            primary_icon: primary_icon,
            timestamp: new DateTime.from_unix_local (data.timestamp),
            dismiss_action_name: data.dismiss_action_name,
            default_action_name: data.default_action_name,
            default_action_target: data.default_action_target,
            buttons: buttons,
            display_hint: data.display_hint
        );
    }

    construct {
        latest_for_app_id[app_id] = timestamp;
    }

    public int compare (Notification other) {
        if (other.app_id == app_id) {
            return timestamp.compare (other.timestamp);
        }

        var latest = latest_for_app_id[app_id];
        var other_latest = latest_for_app_id[other.app_id];

        return latest.compare (other_latest);
    }
}
