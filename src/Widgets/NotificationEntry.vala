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
	private Notification notification;
    private Gtk.Image icon;
    //private Gtk.Label time_label;

    private string entry_icon;
    private string entry_summary;
    private string entry_body;

    public Gtk.Button clear_btn;
    public bool active = true;

    public NotificationEntry (Notification _notification, bool first_item = false) {
    	this.notification = _notification;
        this.entry_icon = notification.icon;
        this.entry_summary = notification.summary;
        this.entry_body = notification.message_body;

        notification.time_changed.connect ((timespan) => {
        	//time_label.label = get_string_from_timespan (timespan);

        	return this.active;
        });

        this.hexpand = true;
        add_widgets (first_item);
    }
    
    private void add_widgets (bool first_item = false) {
        if (entry_icon == "")
            icon = new Gtk.Image.from_icon_name ("help-info", Gtk.IconSize.LARGE_TOOLBAR);
        else if (entry_icon.has_prefix ("/"))
            icon = new Gtk.Image.from_file (entry_icon);
        else
            icon = new Gtk.Image.from_icon_name (entry_icon, Gtk.IconSize.LARGE_TOOLBAR);    

        icon.use_fallback = true;      
        icon.set_alignment (0, 0);

        var root_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        
        var title_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 90);
        title_box.hexpand = true;

        var title_label = new Gtk.Label ("<b>%s</b>".printf (entry_summary));
        title_label.max_width_chars = 20;
        title_label.set_alignment (0, 0);
        title_label.margin_top = 4;
        title_label.use_markup = true;
        title_label.set_line_wrap (true);
        title_label.wrap_mode = Pango.WrapMode.WORD;
          
        var body_label = new Gtk.Label (entry_body);
        body_label.set_line_wrap (true);
        body_label.wrap_mode = Pango.WrapMode.WORD;  
        body_label.set_alignment (0, 0);

        //time_label = new Gtk.Label ("");
        //time_label.margin_end = 2;
        //time_label.get_style_context ().add_class ("h4");

        clear_btn = new Gtk.Button.with_label ("Clear");   
        clear_btn.margin_end = 2;

        var btn_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        btn_box.pack_start (clear_btn, false, false, 0);

        title_box.pack_start (title_label, false, false, 0);
        title_box.pack_end (btn_box, false, false, 0);

        vbox.add (title_box);
        vbox.add (body_label);       
        hbox.pack_start (icon, false, false, 0);
        
        hbox.add (vbox);
        if (!first_item)
        	root_vbox.add (new Wingpanel.Widgets.IndicatorSeparator ());  
        root_vbox.add (hbox); 
        this.add (root_vbox);  
        this.show_all (); 
    }

    private string get_string_from_timespan (TimeSpan timespan) {
    	string suffix = "s";
    	int64 time = (timespan / timespan.SECOND) * -1;
    	if (time > 59) {
    		suffix = " min";
    		time = time / 60;

    		if (time > 59) {
    			suffix = "h";
    			time = time / 60;

		    	if (time > 23) {
		    		suffix = " days";
		    		time = time / 24;
		    	}    			
    		}
    	}

    	return time.to_string () + suffix;
    }
}
