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

    private Gtk.Stack content_area;
    private static Regex entity_regex;
    private static Regex tag_regex;

    public NotificationEntry (Notification notification) {
        Object (notification: notification);
    }

    construct {
        var contents = new Contents (notification);

        content_area = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.SLIDE_DOWN,
            vhomogeneous = false
        };
        content_area.add (contents);

        margin = 12;
        margin_top = 0;
        add (content_area);
        get_style_context ().add_class (Granite.STYLE_CLASS_CARD);
        get_style_context ().add_class (Granite.STYLE_CLASS_ROUNDED);
        show_all ();

        if (notification.data_session) {
            notification.time_changed (notification.timestamp);
        }

        notification.closed.connect (() => clear ());
    }

    public void replace (Notification notification) {
        var new_contents = new Contents (notification);
        new_contents.show_all ();

        content_area.add (new_contents);
        content_area.visible_child = new_contents;
    }

    private class Contents : Gtk.Grid {
        public Notification notification { get; construct; }

        public Contents (Notification notification) {
            Object (notification: notification);
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
            /*Only summary is required by GLib, so try to set a title when body is empty*/
            string body = notification.message_body;
            string summary = notification.summary;
            if (body == "") {
                body = notification.summary;
                summary = notification.app_name;
            }

            string app_icon = "dialog-information";
            if (notification.app_icon == "") {
                if (notification.app_info != null) {
                    app_icon = notification.app_info.get_icon ().to_string ();
                }
            }

            var app_image = new Gtk.Image ();
            app_image.icon_name = app_icon;
            app_image.pixel_size = 48;

            var title_label = new Gtk.Label ("<b>%s</b>".printf (fix_markup (notification.summary))) {
                ellipsize = Pango.EllipsizeMode.END,
                max_width_chars = 33,
                use_markup = true,
                valign = Gtk.Align.END,
                width_chars = 33,
                xalign = 0
            };

            var time_label = new Gtk.Label (Granite.DateTime.get_relative_datetime (notification.timestamp));
            time_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            body = fix_markup (body);

            var body_label = new Gtk.Label (body) {
                ellipsize = Pango.EllipsizeMode.END,
                lines = 2,
                max_width_chars = 33,
                use_markup = true,
                valign = Gtk.Align.START,
                width_chars = 33,
                wrap = true,
                xalign = 0
            };

            if ("\n" in body) {
                string[] lines = body.split ("\n");
                string stripped_body = lines[0] + "\n";
                for (int i = 1; i < lines.length; i++) {
                    stripped_body += lines[i].strip () + "";
                }

                body_label.label = stripped_body.strip ();
                body_label.lines = 1;
            }

            column_spacing = 6;
            margin = 6;
            attach (app_image, 0, 0, 1, 2);
            attach (title_label, 1, 0);
            attach (time_label, 2, 0);
            attach (body_label, 1, 1, 2);

            notification.time_changed.connect ((timestamp) => {
                time_label.label = Granite.DateTime.get_relative_datetime (timestamp);

                return true;
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
}
