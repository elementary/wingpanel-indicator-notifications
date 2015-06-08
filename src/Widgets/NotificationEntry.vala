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

        var style_context = this.get_style_context ();
        style_context.remove_class ("button");
        style_context.remove_class ("list-row");
        style_context.add_class ("menuitem");
        style_context.add_class ("flat");

        notification.time_changed.connect ((timespan) => {
            if (!indicator_opened)
                time_label.label = get_string_from_timespan (timespan);

            return this.active;
        });

        this.hexpand = true;
        add_widgets ();
    }
    
    private void add_widgets () {
        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        hbox.margin_start = 30;

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        
        var title_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 25);
        title_box.hexpand = true;

        var title_label = new Gtk.Label (entry_summary);
        title_label.lines = 3;
        title_label.get_style_context ().add_class ("h4");
        title_label.ellipsize = Pango.EllipsizeMode.END;
        title_label.max_width_chars = 40;
        title_label.set_alignment (0, 0);
        title_label.use_markup = true;
        title_label.set_line_wrap (true);
        title_label.wrap_mode = Pango.WrapMode.CHAR;
          
        var body_label = new Gtk.Label (entry_body);
        body_label.set_alignment (0, 0);
        body_label.set_line_wrap (true);
        body_label.wrap_mode = Pango.WrapMode.WORD;  

        time_label = new Gtk.Label ("now");
        time_label.margin_end = 2;

        clear_btn = new Gtk.Button.from_icon_name ("edit-clear-symbolic", Gtk.IconSize.SMALL_TOOLBAR);  
        clear_btn.margin_top = 2; 
        clear_btn.margin_end = clear_btn.margin_top;
        clear_btn.get_style_context ().add_class ("flat");

        var box_btn = new Gtk.Grid ();
        box_btn.attach (time_label, 0, 1, 1, 1);
        box_btn.attach (clear_btn, 1, 1, 1, 1);

        title_box.pack_start (title_label, false, false, 0);
        title_box.pack_end (box_btn, false, false, 0);

        vbox.add (title_box);
        vbox.add (body_label);       
        
        hbox.add (vbox);
        this.add (hbox);  
        this.show_all (); 
    }

    private string? get_string_from_timespan (TimeSpan timespan) {
        string suffix = _("min");
        int64 time = (timespan / timespan.MINUTE) * -1;
        if (time > 59) {
            suffix = "h";
            time = time / 60;

            if (time > 23) {
                if (time == 1)
                    suffix = " " + _("day");
                else    
                    suffix = " " + _("days");
                time = time / 24;
            }               
        }

        return time.to_string () + suffix;
    }
}
