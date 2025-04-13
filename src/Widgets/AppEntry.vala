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

public class Notifications.AppEntry : Granite.Bin {
    private static Gtk.CssProvider provider;
    private static Settings settings;
    private static HashTable<string, bool> headers;

    static construct {
        provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/elementary/wingpanel/notifications/AppEntry.css");
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        settings = new Settings ("io.elementary.wingpanel.notifications");
        headers = (HashTable<string, bool>) settings.get_value ("headers");
    }

    public unowned Gtk.ListHeader header { get; construct; }

    private string app_id;

    private Gtk.Label label;
    private Gtk.Button clear_btn_entry;
    private Gtk.ToggleButton expander;

    public AppEntry (Gtk.ListHeader header) {
        Object (header: header);
    }

    construct {
        var image = new Gtk.Image.from_icon_name ("pan-end-symbolic");

        label = new Gtk.Label (null) {
            hexpand = true,
            xalign = 0
        };
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var expander_content = new Gtk.Box (HORIZONTAL, 3);
        expander_content.append (label);
        expander_content.append (image);

        expander = new Gtk.ToggleButton () {
            child = expander_content,
            active = true
        };
        unowned var expander_style_context = expander.get_style_context ();
        expander_style_context.add_class ("image-button");
        expander_style_context.add_class ("expander");

        var clear_btn_image = new Gtk.Image.from_icon_name ("edit-clear-all-symbolic");
        clear_btn_image.get_style_context ().add_class ("sweep-animation");

        clear_btn_entry = new Gtk.Button () {
            child = clear_btn_image
        };
        clear_btn_entry.get_style_context ().add_class (Granite.STYLE_CLASS_FLAT);

        var box = new Gtk.Box (HORIZONTAL, 6);
        box.append (expander);
        box.append (clear_btn_entry);

        margin_start = 12;
        margin_end = 12;
        margin_bottom = 3;
        margin_top = 6;
        can_focus = false;
        child = box;

        expander.toggled.connect (expander_toggled);

        clear_btn_entry.clicked.connect (() => {
            clear_btn_image.get_style_context ().add_class ("active");
            clear_section ();
        });

        expander.bind_property ("active", image, "tooltip-text", SYNC_CREATE, (binding, srcval, ref targetval) => {
            targetval = (bool) srcval ? _("Show less") : _("Show more");
            return true;
        });
    }

    private void expander_toggled () {
        headers[app_id] = expander.active;
        settings.set_value ("headers", headers);

        if (expander.active) {
            activate_action_variant (NotificationsList.INTERNAL_ACTION_PREFIX + NotificationsList.ACTION_UPDATE_SECTION, new Variant ("(uuu)", header.start, header.end, NotificationsList.UpdateKind.EXPAND));
        } else {
            activate_action_variant (NotificationsList.INTERNAL_ACTION_PREFIX + NotificationsList.ACTION_UPDATE_SECTION, new Variant ("(uuu)", header.start, header.end, NotificationsList.UpdateKind.COLLAPSE));
        }
    }

    private void clear_section () {
        activate_action_variant (NotificationsList.INTERNAL_ACTION_PREFIX + NotificationsList.ACTION_UPDATE_SECTION, new Variant ("(uuu)", header.start, header.end, NotificationsList.UpdateKind.DISMISS));
    }

    public void bind (Notification notification) {
        app_id = notification.app_id;

        var app_info = new DesktopAppInfo (app_id + ".desktop");

        unowned string name;
        if (app_info != null) {
            name = app_info.get_name ();
        } else {
            name = _("Other");
        }

        label.label = name;
        clear_btn_entry.tooltip_text = _("Clear all %s notifications").printf (name);

        if (app_id in headers) {
            expander.active = headers[app_id];
        }
    }
}
