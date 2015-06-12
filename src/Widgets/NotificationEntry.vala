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

    public NotificationEntry (Notification _notification) {
        this.notification = _notification;
        this.entry_summary = notification.summary;
        this.entry_body = notification.message_body;

        this.get_style_context ().add_class ("menuitem");

        notification.time_changed.connect ((timespan) => {
            if (!indicator_opened) {
                string? label = get_string_from_timespan (timespan);
                if (label != null)
                    time_label.label = label;
            }

            return this.active;
        });

        this.hexpand = true;
        add_widgets ();
    }
    
    private void add_widgets () {
        var grid = new Gtk.Grid ();
        grid.margin_start = 32;

        var title_label = new Gtk.Label ("<b>" + entry_summary + "</b>");
        ((Gtk.Misc) title_label).xalign = 0.0f;
        title_label.hexpand = true;
        title_label.use_markup = true;
        title_label.set_line_wrap (true);
        title_label.wrap_mode = Pango.WrapMode.WORD;

        title_label.margin_top = 6;
        title_label.margin_bottom = 6;

        var body_label = new Gtk.Label (entry_body);
        ((Gtk.Misc) body_label).xalign = 0.0f;
        body_label.set_line_wrap (true);
        body_label.wrap_mode = Pango.WrapMode.WORD;

        time_label = new Gtk.Label (_("now"));

        clear_btn = new Gtk.Button.from_icon_name ("edit-clear-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        clear_btn.get_style_context ().add_class ("flat");

        var box_btn = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        box_btn.valign = Gtk.Align.START;
        box_btn.add (time_label);
        box_btn.add (clear_btn);

        grid.attach (title_label, 0, 0, 1, 1);
        grid.attach (box_btn, 1, 0, 1, 1);
        grid.attach (body_label, 0, 1, 2, 1);

        this.add (grid);
        this.show_all ();
    }

    private string? get_string_from_timespan (TimeSpan timespan) {
        string suffix = _("min");
        int64 time = (timespan / timespan.MINUTE) * -1;
        if (time > 59) {
            suffix = _("h");
            time = time / 60;

            if (time > 23) {
                if (time == 1)
                    suffix = " " + _("day");
                else    
                    suffix = " " + _("days");
                time = time / 24;
            }               
        } else 
            return null;

        return time.to_string () + suffix;
    }
}
