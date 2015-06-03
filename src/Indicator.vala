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

using GLib;

public class Indicator : Wingpanel.Indicator {
    private const string SETTINGS_EXEC = "switchboard notifications";
    private Wingpanel.Widgets.DynamicIcon dynamic_icon;
    private Gtk.Box? main_box = null;
    private Wingpanel.Widgets.IndicatorButton clear_all_btn;

    private NotificationsList nlist;
    private NotificationMonitor monitor;

    public Indicator () {
        GLib.Object (code_name: Wingpanel.Indicator.MESSAGES,
                display_name: _("Notifications indicator"),
                description:_("The notifications indicator"));

        this.visible = true;
        monitor = new NotificationMonitor ();
    }

    public override Gtk.Widget get_display_widget () {
        if (dynamic_icon == null) {
            dynamic_icon = new Wingpanel.Widgets.DynamicIcon ("indicator-messages");
        }

        //dynamic_icon.set_icon_name ("indicator-messages-new");

        return dynamic_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (main_box == null) {
            main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            var stack = new Gtk.Stack ();

            var no_notifications = new Gtk.Label ("<i>%s</i>".printf ("There are no new notifications."));
            no_notifications.use_markup = true;
            no_notifications.margin_top = no_notifications.margin_bottom = 50;

            nlist = new NotificationsList ();
            stack.add_named (nlist, "list");
            stack.add_named (no_notifications, "no-notifications");

            clear_all_btn = new Wingpanel.Widgets.IndicatorButton (_("Clear all notifications..."));
            clear_all_btn.clicked.connect (nlist.clear_all);

            var settings_btn = new Wingpanel.Widgets.IndicatorButton (_("Notifications Settings…"));
            settings_btn.clicked.connect (show_settings);

            nlist.switch_stack.connect ((list) => {
                if (list) {
                    stack.set_visible_child (nlist);
                    clear_all_btn.set_visible (true);
                } else {
                    stack.set_visible_child (no_notifications);
                    dynamic_icon.set_icon_name ("indicator-messages");
                    clear_all_btn.set_visible (false);
                }
            });

            monitor.received.connect ((message) => {
                var notification = new Notification.from_message (message);
                var entry = new NotificationEntry (notification);
                nlist.add_item (entry);

                dynamic_icon.set_icon_name ("indicator-messages-new");
            });

            main_box.add (stack);
            main_box.add (clear_all_btn);
            main_box.add (settings_btn);
            main_box.show_all ();
            nlist.clear_all ();
        }

        return main_box;
    }

    public override void opened () {
        if (nlist.get_items_length () > 0)
            clear_all_btn.set_visible (true);
        else
            clear_all_btn.set_visible (false);    
    }

    public override void closed () {

    }

    private void show_settings () {
        var cmd = new Granite.Services.SimpleCommand ("/usr/bin", SETTINGS_EXEC);
        cmd.run ();
    }    
}

public Wingpanel.Indicator get_indicator (Module module) {
    debug ("Activating Notifications Indicator");
    var indicator = new Indicator ();
    return indicator;
}
    