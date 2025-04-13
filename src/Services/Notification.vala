/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Portal.Notification : Object {
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
        public string internal_id;
        public HashTable<string, Variant> raw_data;
        public string app_id;
        public string dismiss_action_name;
        public string default_action_name;
        public Variant[] default_action_target;
        public Button.Data[] buttons;
        public DisplayHint display_hint;
    }

    public string internal_id { get; construct; }

    public string title { get; construct; }
    public string body { get; construct; }

    public Icon primary_icon { get; construct; }

    public DateTime timestamp { get; construct; }

    public string dismiss_action_name { get; construct; }
    public string default_action_name { get; construct; }
    public Variant? default_action_target { get; construct; }
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
            internal_id: data.internal_id,
            title: title,
            body: body,
            primary_icon: primary_icon,
            dismiss_action_name: data.dismiss_action_name,
            default_action_name: data.default_action_name,
            default_action_target: maybe_from_array (data.default_action_target),
            buttons: buttons,
            display_hint: data.display_hint
        );
    }
}

private static Variant? maybe_from_array (Variant[] array) {
    if (array.length == 0) {
        return null;
    }

    return array[0];
}
