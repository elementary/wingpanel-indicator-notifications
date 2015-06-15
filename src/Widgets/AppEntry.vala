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

public class AppEntry : Gtk.ListBoxRow {
    public string app_name;
    public Gtk.Button clear_btn_entry;
    public AppInfo? appinfo = null;
    public Wnck.Window? app_window;

    public signal void destroy_entry ();

    private List<NotificationEntry> app_notifications;
    
    public AppEntry (NotificationEntry entry, Wnck.Window? _app_window) {
        var notification = entry.notification;
        this.app_name = notification.app_name;
        this.app_window = _app_window;

        app_notifications = new List<NotificationEntry> ();
        this.add_notification_entry (entry);

        appinfo = Utils.get_appinfo_from_app_name (app_name);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.hexpand = true;

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);

        /* Capitalize the first letter */
        char[] utf8 = notification.display_name.to_utf8 ();
        utf8[0] = utf8[0].toupper ();

        var label = new Gtk.Label (string.join ("", utf8));
        label.get_style_context ().add_class ("h3");

        clear_btn_entry = new Gtk.Button.with_label (_("Clear"));
        clear_btn_entry.margin_end = 2;
        clear_btn_entry.clicked.connect (() => {
            app_notifications.@foreach ((entry) => {
                entry.clear_btn.clicked ();   
            });
            
            this.destroy_entry ();
        });

        /*app_window.notify["is_above"].connect (() => {
            print ("SIGNALLLL!\n");
        });

        app_window.actions_changed.connect ((mask, new_action) => {
            print ("ACTION: %i\n", new_action);
        });

        app_window.state_changed.connect ((mask, new_state) => {
            print ("STATE: %i\n", new_state);
            if (new_state == 0)
                clear_btn_entry.clicked ();
        });*/

        string icon = "";
        if (notification.app_icon == "") {
            var glib_icon = appinfo.get_icon ();
            icon = glib_icon.to_string ();
        } else    
            icon = notification.app_icon;        

        var image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.LARGE_TOOLBAR);
        hbox.pack_start (image, false, false, 0);
        hbox.pack_start (label, false, false, 0);
        hbox.pack_end (clear_btn_entry, false, false, 0);

        this.connect_entry (entry);

        vbox.add (hbox);
        this.add (vbox);
        this.show_all ();
    }

    private void connect_entry (NotificationEntry entry) {
        entry.notify["active"].connect (() => {
            if (!entry.active) {
                this.remove_notification_entry (entry);
                entry.unref ();
            }
        });
    }

    public unowned List<NotificationEntry> get_notifications () {
        return this.app_notifications;
    }

    public void add_notification_entry (NotificationEntry entry) {
        app_notifications.prepend (entry);
        this.connect_entry (entry);
    }

    public void remove_notification_entry (NotificationEntry entry) {
        app_notifications.remove (entry);
        if (app_notifications.length () == 0)
            this.destroy_entry ();
    }
}