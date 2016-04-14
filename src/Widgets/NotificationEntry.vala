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

public class NotificationEntry : Gtk.ListBoxRow {
    public Notification notification;

    private Gtk.Label time_label;

    private string entry_summary;
    private string entry_body;

    public Gtk.Button clear_btn;
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
        this.notification = _notification;
        this.entry_summary = notification.summary;
        this.entry_body = notification.message_body;

        this.get_style_context ().add_class ("menuitem");

        notification.time_changed.connect ((timespan) => {
            string label = get_string_from_timespan (timespan);
            time_label.label = label;

            return this.active;
        });

        this.hexpand = true;
        add_widgets ();

        if (notification.data_session)
            notification.time_changed (notification.timestamp.difference (new DateTime.now_local ()));
    }

    private void add_widgets () {
        var grid = new Gtk.Grid ();
        grid.margin_start = 40;

        var title_label = new Gtk.Label ("<b>" + fix_markup (entry_summary) + "</b>");
        ((Gtk.Misc) title_label).xalign = 0.0f;
        title_label.hexpand = true;
        title_label.use_markup = true;
        title_label.set_line_wrap (true);
        title_label.wrap_mode = Pango.WrapMode.WORD;

        time_label = new Gtk.Label (_("now"));

        clear_btn = new Gtk.Button.from_icon_name ("edit-clear-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        clear_btn.get_style_context ().add_class ("flat");

        var box_btn = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        box_btn.valign = Gtk.Align.START;
        box_btn.add (time_label);
        box_btn.add (clear_btn);

        grid.attach (title_label, 0, 0, 1, 1);
        grid.attach (box_btn, 1, 0, 1, 1);

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

        this.add (grid);
        this.show_all ();
    }

    /**
     * Copied from gnome-shell, fixes the mess of markup that is sent to us
     */
    string fix_markup (string markup) {
        var text = markup;

        try {
            text = entity_regex.replace (markup, markup.length, 0, "&amp;");
            text = tag_regex.replace (text, text.length, 0, "&lt;");
        } catch (Error e) {
            warning ("Invalid regex: %s", e.message);
        }

        return text;
    }

    private string get_string_from_timespan (TimeSpan timespan) {
        if (-timespan >= GLib.TimeSpan.DAY) {
            ulong days = (ulong)(-timespan/GLib.TimeSpan.DAY);
            return dngettext (Config.GETTEXT_PACKAGE, "%ld day", "%ld days", days).printf (days);
        } else if (-timespan >= TimeSpan.HOUR) {
            ulong hours = (ulong)(-timespan/GLib.TimeSpan.HOUR);
            return dngettext (Config.GETTEXT_PACKAGE, "%ld hour", "%ld hours", hours).printf (hours);
        } else if (-timespan >= GLib.TimeSpan.MINUTE) {
            ulong minutes = (ulong)(-timespan/GLib.TimeSpan.MINUTE);
            return dngettext (Config.GETTEXT_PACKAGE, "%ld minute", "%ld minutes", minutes).printf (minutes);
        } else {
            return _("Now");
        }
    }

    // This won't be used but we need it to be included in the translation template.
    private void translations () {
        ngettext ("%ld day", "%ld days", 0);
        ngettext ("%ld hour", "%ld hours", 0);
        ngettext ("%ld minute", "%ld minutes", 0);
    }
}
