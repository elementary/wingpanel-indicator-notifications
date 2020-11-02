/*-
 * Copyright 2015-2020 elementary, Inc (https://elementary.io)
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
    public signal void clear_app (string app_id);
    public signal void remove_notification (Notification notification);

    private GLib.GenericArray<Notifications.AppEntry> apps;

    construct {
        apps = new GLib.GenericArray<Notifications.AppEntry> ();

        var placeholder = new Gtk.Label (_("No Notifications"));
        placeholder.margin_top = placeholder.margin_bottom = 24;
        placeholder.margin_start = placeholder.margin_end = 12;
        placeholder.show ();

        unowned Gtk.StyleContext placeholder_style_context = placeholder.get_style_context ();
        placeholder_style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        activate_on_single_click = true;
        selection_mode = Gtk.SelectionMode.NONE;
        set_placeholder (placeholder);
        set_header_func (header_func);
        show_all ();

        row_activated.connect (on_row_activated);
    }

    public NotificationsList (GLib.ListModel list_model) {
        bind_model (list_model, create_notification);
    }

    private Gtk.Widget create_notification (GLib.Object object) {
        unowned Notification notification = (Notifications.Notification) object;
        var notification_entry = new NotificationEntry (notification);
        notification_entry.removed.connect (() => {
            remove_notification (notification);
        });

        notification_entry.show_all ();
        return notification_entry;
    }

    private void header_func (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
        unowned NotificationEntry row_entry = (NotificationEntry) row;
        unowned NotificationEntry? before_entry = (NotificationEntry) before;
        unowned string row_app_id = row_entry.notification.desktop_id;
        if (before == null || row_app_id != before_entry.notification.desktop_id) {
            for (uint i = 0; i < apps.length; i++) {
                unowned AppEntry app = apps.get (i);
                if (app.app_id == row_app_id) {
                    row.set_header (app);
                    return;
                }
            }

            var app_entry = new AppEntry (row_entry.notification.app_info);
            app_entry.show_all ();
            app_entry.clear.connect (() => { remove_app (app_entry); });
            row.set_header (app_entry);
        } else {
            row.set_header (null);
        }
    }

    private void remove_app (AppEntry entry) {
        clear_app (entry.app_id);
        apps.remove_fast (entry);
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        unowned NotificationEntry notification_entry = (NotificationEntry) row;
        notification_entry.notification.run_default_action ();
        notification_entry.dismiss ();
        close_popover ();
    }
}
