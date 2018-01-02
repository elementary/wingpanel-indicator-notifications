/*-
 * Copyright (c) 2015 Wingpanel Developers (http://launchpad.net/wingpanel)
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

    public Notification notification;

    private Gtk.Label time_label;

    private string entry_summary;
    private string entry_body;

    public bool active = true;

    static Regex entity_regex;
    static Regex tag_regex;

    static construct {
        try {
            entity_regex = new Regex ("&(?!amp;|quot;|apos;|lt;|gt;)");
            tag_regex = new Regex ("<(?!\\/?[biu]>)");
        } catch (Error e) {
            warning ("Invalid regex: %s", e.message);
        }
    }

    public NotificationEntry (Notification _notification) {
        notification = _notification;
        entry_summary = notification.summary;
        entry_body = notification.message_body;

        get_style_context ().add_class ("menuitem");

        notification.time_changed.connect ((timestamp) => {
            time_label.label = Granite.DateTime.get_relative_datetime (timestamp);

            return active;
        });

        notification.closed.connect (() => clear ());

        hexpand = true;

        var grid = new Gtk.Grid ();
        grid.margin_start = 40;
        grid.margin_end = 6;

        var title_label = new Gtk.Label ("<b>" + fix_markup (entry_summary) + "</b>");
        title_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
        title_label.max_width_chars = 32;
        ((Gtk.Misc) title_label).xalign = 0.0f;
        title_label.hexpand = true;
        title_label.use_markup = true;
        title_label.set_line_wrap (true);
        title_label.wrap_mode = Pango.WrapMode.WORD;

        time_label = new Gtk.Label (_("now"));

        grid.attach (title_label, 0, 0, 1, 1);
        grid.attach (time_label, 1, 0, 1, 1);

        if (entry_body != "") {
            var body_label = new Gtk.Label (fix_markup (entry_body));
            ((Gtk.Misc) body_label).xalign = 0.0f;
            body_label.margin_bottom = 6;
            body_label.margin_end = 3;
            body_label.use_markup = true;
            body_label.set_line_wrap (true);
            body_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            body_label.max_width_chars = 32;
            grid.attach (body_label, 0, 1, 2, 1);
        }

        add (grid);
        show_all ();

        if (notification.data_session) {
            notification.time_changed (notification.timestamp);
        }
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
