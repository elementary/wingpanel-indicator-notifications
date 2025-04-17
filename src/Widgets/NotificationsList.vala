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
    public enum UpdateKind {
        EXPAND,
        COLLAPSE,
        DISMISS
    }

    public signal void close_popover ();

    public const string NOTIFICATION_ACTION_GROUP_PREFIX = "notification";
    public const string NOTIFICATION_ACTION_PREFIX = NOTIFICATION_ACTION_GROUP_PREFIX + ".";

    public const string ACTION_GROUP_PREFIX = "notifications-list";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string ACTION_UPDATE_SECTION = "update-section";

    public NotificationModel model { get; construct; }

    construct {
        var provider = new NotificationProvider ();

        model = new NotificationModel (provider);

        var placeholder = new Gtk.Label (_("No Notifications")) {
            margin_top = 24,
            margin_bottom = 24,
            margin_start = 12,
            margin_end = 12,
            visible = true
        };

        unowned Gtk.StyleContext placeholder_style_context = placeholder.get_style_context ();
        placeholder_style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        activate_on_single_click = true;
        selection_mode = Gtk.SelectionMode.NONE;
        set_placeholder (placeholder);
        set_header_func (header_func);
        bind_model (model, create_entry_func);
        show_all ();

        insert_action_group (NOTIFICATION_ACTION_GROUP_PREFIX, provider.action_group);

        var section_action = new SimpleAction (ACTION_UPDATE_SECTION, new VariantType ("(uu)"));
        section_action.activate.connect (update_section);

        var action_group = new SimpleActionGroup ();
        action_group.add_action (section_action);

        insert_action_group (ACTION_GROUP_PREFIX, action_group);
    }

    private void header_func (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
        var notification = ((NotificationEntry) row).notification;

        if (before != null && notification.app_id == ((NotificationEntry) before).notification.app_id) {
            return;
        }

        var info = new DesktopAppInfo (notification.app_id + ".desktop");
        row.set_header (new AppEntry (info, row));
    }

    private Gtk.Widget create_entry_func (Object obj) {
        var notification = (Notification) obj;
        return new NotificationEntry (notification);
    }

    private void update_section (Variant? parameter) {
        uint start, kind;
        parameter.get ("(uu)", out start, out kind);

        var app_id = ((Notification) model.get_item (start)).app_id;
        update_items (start, app_id, kind);
    }

    public void update_items (uint start, string? app_id, UpdateKind kind) {
        for (uint i = start; i < model.get_n_items (); i++) {
            var notification = (Notification) model.get_item (i);
            if (app_id != null && notification.app_id != app_id) {
                break;
            }

            switch (kind) {
                case UpdateKind.EXPAND:
                case UpdateKind.COLLAPSE:
                    notification.collapsed = kind == UpdateKind.COLLAPSE;
                    break;

                case UpdateKind.DISMISS:
                    get_action_group (NOTIFICATION_ACTION_GROUP_PREFIX).activate_action (notification.dismiss_action_name, null);
                    break;
            }
        }
    }
}
