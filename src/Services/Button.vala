/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Notifications.Button : Object {
    public struct Data {
        public string label;
        public string action_name;
        public Variant[] action_target;
    }

    public string label { get; construct; }
    public string action_name { get; construct; }
    public Variant? action_target { get; construct; }

    public Button (Data data) {
        Object (
            label: data.label,
            action_name: data.action_name,
            action_target: Utils.maybe_from_array (data.action_target)
        );
    }
}
