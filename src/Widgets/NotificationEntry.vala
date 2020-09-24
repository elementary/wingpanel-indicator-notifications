/*-
 * Copyright (c) 2015-2018 elementary LLC. (https://elementary.io)
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

public class Notifications.NotificationEntry : Gtk.ListBoxRow {
    public signal void clear ();
    public bool active = true;
    public Notification notification { get; construct; }
    public NotificationsList nlist { get; construct; }

    private static Regex entity_regex;
    private static Regex tag_regex;

    private Hdy.Carousel carousel;

    public NotificationEntry (Notification notification, NotificationsList nlist) {
        Object (notification: notification,
                nlist: nlist
        );
    }

    static construct {
        try {
            entity_regex = new Regex ("&(?!amp;|quot;|apos;|lt;|gt;)");
            tag_regex = new Regex ("<(?!\\/?[biu]>)");
        } catch (Error e) {
            warning ("Invalid regex: %s", e.message);
        }
    }

    construct {
        carousel = new Hdy.Carousel () {
            allow_mouse_drag = true,
            interactive = true
        };

        var app_icon = notification.app_icon;
        if (app_icon == "") {
            if (notification.app_info != null) {
                app_icon = notification.app_info.get_icon ().to_string ();
            } else {
                app_icon = "dialog-information";
            }
        }

        var app_image = new Gtk.Image () {
            icon_name = app_icon,
            pixel_size = 48,
            margin = 6,
            margin_right = 0
        };

        var title_label = new Gtk.Label ("<b>%s</b>".printf (fix_markup (notification.summary))) {
            ellipsize = Pango.EllipsizeMode.END,
            hexpand = true,
            width_chars = 27,
            max_width_chars = 27,
            use_markup = true,
            xalign = 0
        };


        var time_label = new Gtk.Label (Granite.DateTime.get_relative_datetime (notification.timestamp)) {
            margin_right = 6
        };
        time_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var grid = new Gtk.Grid () {
            hexpand = true,
            column_spacing = 6,
            margin = 12,
            margin_top = 1,
            margin_bottom = 11
        };

        grid.get_style_context ().add_class (Granite.STYLE_CLASS_CARD);
        grid.get_style_context ().add_class (Granite.STYLE_CLASS_ROUNDED);

        grid.attach (app_image, 0, 0, 1, 2);
        grid.attach (title_label, 1, 0);
        grid.attach (time_label, 2, 0);
        var entry_body = notification.message_body;
        if (entry_body != "") {
            var body = fix_markup (entry_body);

            var body_label = new Gtk.Label (body) {
                ellipsize = Pango.EllipsizeMode.END,
                lines = 2,
                use_markup = true,
                valign = Gtk.Align.START,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                wrap = true,
                xalign = 0
            };

            if ("\n" in body) {
                string[] lines = body.split ("\n");
                string stripped_body = lines[0] + "\n";
                for (int i = 1; i < lines.length; i++) {
                    stripped_body += lines[i].strip () + " ";
                }

                body_label.label = stripped_body.strip ();
                body_label.lines = 1;

            }

            grid.attach (body_label, 1, 1, 2);
        }

        carousel.add (grid);
        carousel.add (new Gtk.Grid ());
        carousel.scroll_to (grid);

        add (carousel);
        show_all ();

        if (notification.data_session) {
            notification.time_changed (notification.timestamp);
        }

        notification.time_changed.connect ((timestamp) => {
            time_label.label = Granite.DateTime.get_relative_datetime (timestamp);

            return active;
        });

        notification.closed.connect (() => clear ());

        carousel.page_changed.connect ((index) => {
            if (index == 1) {
                nlist.remove_entry (this);
            }
        });

    }

    /**
     * Copied from gnome-shell, fixes the mess of markup that is sent to us
     */
    private string fix_markup (string markup) {
        var text = markup;

        try {
            text = entity_regex.replace (markup, markup.length, 0, "&amp;");
            text = tag_regex.replace (text, text.length, 0, "&lt;");
        } catch (Error e) {
            warning ("Invalid regex: %s", e.message);
        }

        return text;
    }
}
