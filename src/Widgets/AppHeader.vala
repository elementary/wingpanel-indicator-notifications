/*-
 * Copyright 2015-2023 elementary, Inc. (https://elementary.io)
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

public class Notifications.AppHeader : Gtk.ListBoxRow {
    public signal void clear ();

    public string app_name { get; construct; }
    public string app_id { get; construct; }
    public bool expanded { get; set; default = false; }

    private static Gtk.CssProvider provider;
    private static Settings settings;
    private static HashTable<string, bool> headers;

    static construct {
        provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/elementary/wingpanel/notifications/AppHeaderExpander.css");

        settings = new Settings ("io.elementary.wingpanel.notifications");
        headers = (HashTable<string, bool>) settings.get_value ("headers");
    }

    public AppHeader (string app_name, string app_id) {
        Object (app_name: app_name, app_id: app_id);
    }

    construct {
        var image = new Gtk.Image.from_icon_name ("pan-end-symbolic", SMALL_TOOLBAR);
        image.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var label = new Gtk.Label (app_name) {
            hexpand = true,
            xalign = 0
        };
        label.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var expander_content = new Gtk.Box (HORIZONTAL, 3);
        expander_content.add (label);
        expander_content.add (image);

        var expander = new Gtk.ToggleButton () {
            child = expander_content,
            active = (!(app_id in headers) || headers[app_id])
        };
        expander.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        expander.get_style_context ().add_class ("image-button");

        var clear_btn_entry = new Gtk.Button.from_icon_name ("edit-clear-all-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
            tooltip_text = _("Clear all %s notifications").printf (app_name)
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

        clear_btn_entry.clicked.connect (() => clear ());

        expander.toggled.connect (() => {
            headers[app_id] = expander.active;
            settings.set_value ("headers", headers);
        });

        expanded = expander.active;
        expander.bind_property ("active", this, "expanded");

        expander.bind_property ("active", image, "tooltip-text", SYNC_CREATE, (binding, srcval, ref targetval) => {
            targetval = (bool) srcval ? _("Show less") : _("Show more");
            return true;
        });

    }
}
