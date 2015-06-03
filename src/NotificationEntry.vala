
public class NotificationEntry : Gtk.ListBoxRow {
    private Gtk.Image icon;
    private string entry_icon;
    private string entry_summary;
    private string entry_body;
    
    public Gtk.Button clear_btn;

    public NotificationEntry (Notification notification) {
        this.entry_icon = notification.icon;
        this.entry_summary = notification.summary;
        this.entry_body = notification.message_body;

        add_widgets ();
    }
    
    private void add_widgets () {
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
        
        var title_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 70);

        var title_label = new Gtk.Label ("<b>%s</b>".printf (entry_summary));
        title_label.max_width_chars = 20;
        title_label.ellipsize = Pango.EllipsizeMode.END;
        title_label.set_alignment (0, 0);
        title_label.margin_top = 4;
        title_label.use_markup = true;
        title_label.set_line_wrap (true);
        title_label.hexpand = true;
        title_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
          
        var body_label = new Gtk.Label (entry_body);
        body_label.set_line_wrap (true);
        body_label.wrap_mode = Pango.WrapMode.WORD;  
        body_label.set_alignment (0, 0);

        clear_btn = new Gtk.Button.with_label ("Clear");   

        title_box.pack_start (title_label, false, false, 0);
        title_box.pack_end (clear_btn, false, false, 0);

        vbox.add (title_box);
        vbox.add (body_label);       
        hbox.pack_start (icon, false, false, 0);
        
        hbox.add (vbox);
        root_vbox.add (hbox); 
        root_vbox.add (new Wingpanel.Widgets.IndicatorSeparator ());  
        this.add (root_vbox);      
    }
}
