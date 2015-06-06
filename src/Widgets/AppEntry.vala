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
    private List<NotificationEntry> app_notifications;
    private Gtk.Button clear_btn_entry;
    public Wingpanel.Widgets.IndicatorSeparator separator;

    public signal void destroy_entry ();

    public AppEntry (NotificationEntry entry) {
        var notification = entry.notification;
        this.app_name = notification.app_name;
        app_notifications = new List<NotificationEntry> ();
        this.add_notification_entry (entry);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.hexpand = true;

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);

        var label = new Gtk.Label (notification.display_name);
        label.get_style_context ().add_class ("h3");

        clear_btn_entry = new Gtk.Button.with_label (_("Clear"));
        clear_btn_entry.margin_end = 2;
        clear_btn_entry.clicked.connect (() => {
            app_notifications.@foreach ((entry) => {
                entry.clear_btn.clicked ();   
            });
            
            this.destroy ();
        });

        var image = new Gtk.Image.from_icon_name (notification.app_icon, Gtk.IconSize.LARGE_TOOLBAR);
        hbox.pack_start (image, false, false, 0);
        hbox.pack_start (label, false, false, 0);
        hbox.pack_end (clear_btn_entry, false, false, 0);

        separator = new Wingpanel.Widgets.IndicatorSeparator ();

        vbox.add (separator);
        vbox.add (hbox);
        this.add (vbox);
        this.show_all ();
    }

    public void add_notification_entry (NotificationEntry entry) {
        app_notifications.prepend (entry);
    }

    public void remove_notification_entry (NotificationEntry entry) {
        app_notifications.remove (entry);
        if (app_notifications.length () == 1)
            this.destroy ();
    }
}