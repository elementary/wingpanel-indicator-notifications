/*-
 * Copyright 2015-2019 elementary, Inc. (https://elementary.io)
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

 public class Notifications.AppEntry : Gtk.Bin {
    private static Gtk.CssProvider provider;
    private static Settings settings;
    private static HashTable<string, bool> headers;

    static construct {
        provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/elementary/wingpanel/notifications/AppEntry.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        settings = new Settings ("io.elementary.wingpanel.notifications");
        headers = (HashTable<string, bool>) settings.get_value ("headers");
    }

    public AppInfo? app_info { get; construct; }
    public unowned Gtk.ListBoxRow row { get; construct; }

    private string app_id;
    private Gtk.ToggleButton expander;

    public AppEntry (AppInfo? app_info, Gtk.ListBoxRow row) {
        Object (app_info: app_info, row: row);
    }

    construct {
        unowned string name;
        if (app_info != null) {
            app_id = app_info.get_id ();
            name = app_info.get_name ();
        } else {
            app_id = "other";
            name = _("Other");
        }

        var image = new Gtk.Image.from_icon_name ("pan-end-symbolic", SMALL_TOOLBAR);

        var label = new Gtk.Label (name) {
            hexpand = true,
            xalign = 0
        };
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var expander_content = new Gtk.Box (HORIZONTAL, 3);
        expander_content.add (label);
        expander_content.add (image);

        expander = new Gtk.ToggleButton () {
            child = expander_content,
            active = true
        };
        unowned var expander_style_context = expander.get_style_context ();
        expander_style_context.add_class ("image-button");
        expander_style_context.add_class ("expander");

        var clear_btn_image = new Gtk.Image.from_icon_name ("edit-clear-all-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        clear_btn_image.get_style_context ().add_class ("sweep-animation");

        var clear_btn_entry = new Gtk.Button () {
            tooltip_text = _("Clear all %s notifications").printf (name),
            child = clear_btn_image
        };
        clear_btn_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var box = new Gtk.Box (HORIZONTAL, 6);
        box.add (expander);
        box.add (clear_btn_entry);

        margin_start = 12;
        margin_end = 12;
        margin_bottom = 3;
        margin_top = 6;
        can_focus = false;
        child = box;
        show_all ();

        if (app_id in headers) {
            expander.active = headers[app_id];
        }

        expander.toggled.connect (() => {
            headers[app_id] = expander.active;
            settings.set_value ("headers", headers);
            update_section (expander.active ? NotificationsList.UpdateKind.EXPAND : NotificationsList.UpdateKind.COLLAPSE);
        });

        clear_btn_entry.clicked.connect (() => {
            clear_btn_image.get_style_context ().add_class ("active");
            update_section (DISMISS);
        });

        expander.bind_property ("active", image, "tooltip-text", SYNC_CREATE, (binding, srcval, ref targetval) => {
            targetval = (bool) srcval ? _("Show less") : _("Show more");
            return true;
        });
    }

    private void update_section (NotificationsList.UpdateKind kind) {
        get_action_group (NotificationsList.ACTION_GROUP_PREFIX).activate_action (
            NotificationsList.ACTION_UPDATE_SECTION,
            new Variant ("(uu)", (uint) row.get_index (), kind)
        );
    }
}
