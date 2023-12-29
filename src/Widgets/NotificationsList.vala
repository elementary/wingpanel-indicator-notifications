/*-
 * Copyright 2015-2023 elementary, Inc (https://elementary.io)
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

public class Notifications.NotificationsList : Gtk.ListBox {
    public signal void close_popover ();

    public const string ACTION_GROUP_PREFIX = "notifications-list";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    public Gee.HashMap<string, AppSection> app_sections { get; private set; }

    construct {
        app_sections = new Gee.HashMap<string, AppSection> ();

        var placeholder = new Gtk.Label (_("No Notifications")) {
            margin_top = 24,
            margin_bottom = 24,
            margin_start = 12,
            margin_end = 12,
            visible = true
        };
        placeholder.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        selection_mode = Gtk.SelectionMode.NONE;
        set_placeholder (placeholder);
        show_all ();

        insert_action_group (ACTION_GROUP_PREFIX, new NotificationsMonitor ().notifications_action_group);
    }

    public async void add_entry (Notification notification, bool add_to_session = true, bool write_file = true) {
        if (app_sections[notification.desktop_id] != null) {
            var app_section = app_sections[notification.desktop_id];

            move_app_section_to_top (app_section);
            app_section.add_notification (notification);
        } else {
            var app_section = new AppSection (notification.app_info);
            app_sections[notification.desktop_id] = app_section;

            prepend (app_section);
            app_section.add_notification (notification);

            app_section.clear.connect (clear_app_section);
            app_section.close_popover.connect (() => close_popover ());
            app_section.activate_action.connect ((action_name, parameter) => {
                unowned var action_group = get_action_group (ACTION_GROUP_PREFIX);
                action_group.activate_action (action_name, parameter);
            });
        }

        show_all ();

        Idle.add (add_entry.callback);
        yield;

        if (add_to_session) { // If notification was obtained from session do not write it back
            Session.get_instance ().add_notification (notification);
        }
    }

    public uint count_notifications (out uint number_of_apps) {
        uint count = 0;
        @foreach ((widget) => {
            var app_section = (AppSection) widget;
            count += app_section.count_notifications ();
        });

        number_of_apps = get_children ().length ();
        return count;
    }

    public void clear_all () {
        var iter = app_sections.map_iterator ();
        while (iter.next ()) {
            var entry = iter.get_value ();
            iter.unset ();
            clear_app_section (entry);
        }

        close_popover ();
    }

    private void move_app_section_to_top (AppSection app_section) {
        if (get_row_at_index (0) != app_section) {
            remove (app_section);
            prepend (app_section);
        }
    }

    private void clear_app_section (AppSection app_section) {
        app_section.clear.disconnect (clear_app_section);
        app_sections.unset (app_section.app_id);
        app_section.clear_all_notification_entries ();
        app_section.destroy ();

        if (app_sections.size == 0) {
            Session.get_instance ().clear ();
        }
    }

    public void close_notification (uint32 id) {
        foreach (unowned var child in get_children ()) {
            var app_section = (AppSection) child;
            if (app_section.close_notification (id)) {
                return;
            }
        }
    }
}
