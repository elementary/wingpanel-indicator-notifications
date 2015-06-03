
public class NotificationsList : Gtk.ListBox {
    public signal void switch_stack (bool list);
    private GenericArray<NotificationEntry> items;
    private Gtk.Label none_av_label;

    public NotificationsList () {
        this.activate_on_single_click = false;
        this.selection_mode = Gtk.SelectionMode.NONE;

        items = new GenericArray<NotificationEntry> ();
        this.show_all ();
    }
    
    public void add_item (NotificationEntry entry) { 
        entry.clear_btn.clicked.connect (() => {
            items.remove (entry);
            this.remove (entry);

            if (items.length == 0)
                clear_all ();
        });

        items.add (entry);
        this.add (entry);
        this.switch_stack (true);
        this.show_all ();
    }
    
    public int get_items_length () {
        return items.length;
    }
    
    public void clear_all () {
        items.@foreach ((item) => {
            items.remove (item);     
        });

        this.switch_stack (false);
        this.show_all ();
    }
}
