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

public class Notifications.AppEntry : Gtk.Grid {
    public signal void clear ();

    public string app_id { get; private set; }
    public AppInfo? app_info { get; construct; }

    public AppEntry (AppInfo? app_info) {
        Object (app_info: app_info);
    }

    construct {
        margin = 12;
        margin_bottom = 3;
        margin_top = 6;
        column_spacing = 6;

        unowned string name;
        if (app_info != null) {
            app_id = app_info.get_id ();
            name = app_info.get_name ();
        } else {
            app_id = "other";
            name = _("Other");
        }

        var label = new Gtk.Label (name);
        label.hexpand = true;
        label.xalign = 0;
        label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var clear_btn_entry = new Gtk.Button.from_icon_name ("edit-clear-all-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
            tooltip_text = _("Clear all %s notifications").printf (name)
        };
        clear_btn_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        add (label);
        add (clear_btn_entry);

        clear_btn_entry.clicked.connect (() => {
            clear ();
        });
    }
}
