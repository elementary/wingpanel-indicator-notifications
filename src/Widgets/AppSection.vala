/*-
 * Copyright 2023 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Notifications.AppSection : Gtk.ListBoxRow {
    public signal void clear ();
    public signal void close_popover ();
    public signal void activate_action (string action_name, GLib.Variant? parameter);

    public string app_id { get; private set; }
    public AppInfo? app_info { get; construct; }

    private Gtk.ListBox notifications_listbox;

    public AppSection (AppInfo? app_info) {
        Object (app_info: app_info);
    }

    construct {
        unowned string app_name;
        if (app_info != null) {
            app_id = app_info.get_id ();
            app_name = app_info.get_name ();
        } else {
            app_id = "other";
            app_name = _("Other");
        }

        var app_header = new AppHeader (app_name, app_id);

        notifications_listbox = new Gtk.ListBox () {
            activate_on_single_click = true,
            selection_mode = Gtk.SelectionMode.NONE
        };

        var revealer = new Gtk.Revealer () {
            child = notifications_listbox,
            reveal_child = app_header.expanded,
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP
        };

        var box = new Gtk.Box (VERTICAL, 6);
        box.add (app_header);
        box.add (revealer);

        can_focus = false;
        child = box;
        show_all ();

        app_header.clear.connect (() => clear ());
        app_header.notify["expanded"].connect (() => {
            revealer.reveal_child = app_header.expanded;
        });
        notifications_listbox.row_activated.connect (on_row_activated);
    }

    public void add_notification (Notification notification) {
        var entry = new NotificationEntry (notification);
        notifications_listbox.prepend (entry);

        entry.clear.connect (remove_notification_entry);
        entry.activate_action.connect (entry_activate_action_callback);
    }

    private void entry_activate_action_callback (string action_name, GLib.Variant? parameter) {
        activate_action (action_name, parameter);
    }

    public void remove_notification_entry (NotificationEntry entry) {
        entry.clear.disconnect (remove_notification_entry);
        entry.activate_action.disconnect (entry_activate_action_callback);

        notifications_listbox.remove (entry);
        entry.dismiss ();

        Session.get_instance ().remove_notification (entry.notification);
        if (notifications_listbox.get_children ().length () == 0) {
            clear ();
        }

        entry.destroy ();
    }

    public void clear_all_notification_entries () {
        Notification[] to_remove = {};

        notifications_listbox.@foreach ((child) => {
            var entry = (NotificationEntry) child;
            to_remove += entry.notification;

            notifications_listbox.remove (child);
            entry.dismiss ();
            entry.destroy ();
        });

        Session.get_instance ().remove_notifications (to_remove);
    }

    public uint count_notifications () {
        return notifications_listbox.get_children ().length ();
    }

    public bool close_notification (uint32 id) {
        foreach (unowned var child in notifications_listbox.get_children ()) {
            unowned var entry = (NotificationEntry) child;
            if (entry.notification.server_id == id) {
                notifications_listbox.remove (child);
                entry.dismiss ();

                if (notifications_listbox.get_children ().length () == 0) {
                    clear ();
                }

                return true;
            }
        }

        return false;
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        unowned var notification_entry = (NotificationEntry) row;

        if (notification_entry.notification.default_action != null) {
            activate_action (notification_entry.notification.default_action, null);
            close_popover ();
        } else {
            try {
                var context = notification_entry.get_display ().get_app_launch_context ();
                notification_entry.notification.app_info.launch (null, context);
                notification_entry.clear ();
                close_popover ();
            } catch (Error e) {
                warning ("Unable to launch app: %s", e.message);
            }
        }
    }
}
