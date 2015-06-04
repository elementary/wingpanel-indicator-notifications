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

public class Indicator : Wingpanel.Indicator {
    private const string SETTINGS_EXEC = "switchboard notifications";
    private Wingpanel.Widgets.DynamicIcon? dynamic_icon = null;
    private Gtk.Box? main_box = null;
    private Wingpanel.Widgets.IndicatorButton clear_all_btn;
    private Gtk.Stack stack;
    private NotDisturbMode not_disturb_box;

    private NotificationsList nlist;
    private NotificationMonitor monitor;
    private NSettings settings;

    public Indicator () {
        GLib.Object (code_name: Wingpanel.Indicator.MESSAGES,
                display_name: _("Notifications indicator"),
                description:_("The notifications indicator"));

        this.visible = true;
        monitor = new NotificationMonitor ();
        settings = new NSettings ();
    }

    public override Gtk.Widget get_display_widget () {
        if (dynamic_icon == null)
            dynamic_icon = new Wingpanel.Widgets.DynamicIcon (get_display_icon_name ());

        dynamic_icon.button_press_event.connect ((e) => {
            if (e.button == Gdk.BUTTON_MIDDLE) {
                settings.do_not_disturb = !settings.do_not_disturb;
                return Gdk.EVENT_STOP;
            }  

            return Gdk.EVENT_PROPAGATE;  
        });

        return dynamic_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (main_box == null) {
            main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            stack = new Gtk.Stack ();
            stack.hexpand = true;

            var no_notifications_label = new Gtk.Label ("<i>%s</i>".printf ("There are no new notifications."));
            no_notifications_label.use_markup = true;
            no_notifications_label.margin_top = no_notifications_label.margin_bottom = 50;

            not_disturb_box = new NotDisturbMode ();

            nlist = new NotificationsList ();

            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.set_policy (Gtk.PolicyType.ALWAYS, Gtk.PolicyType.ALWAYS);
            scrolled.add (nlist);

            stack.add_named (scrolled, "list");
            stack.add_named (no_notifications_label, "no-notifications");
            stack.add_named (not_disturb_box, "not-disturb-mode");

            clear_all_btn = new Wingpanel.Widgets.IndicatorButton (_("Clear All Notifications"));
            clear_all_btn.clicked.connect (nlist.clear_all);

            var settings_btn = new Wingpanel.Widgets.IndicatorButton (_("Notifications Settings…"));
            settings_btn.clicked.connect (show_settings);

            nlist.switch_stack.connect ((list) => {
                if (list) {
                    main_box.set_size_request (300, 200);
                    stack.set_visible_child (scrolled);
                    clear_all_btn.set_visible (true);
                } else {
                    if (!settings.do_not_disturb) {
                        main_box.set_size_request (200, 50);
                        stack.set_visible_child (no_notifications_label);
                        dynamic_icon.set_icon_name ("indicator-messages");
                        clear_all_btn.set_visible (false);
                    }
                }
            });

            monitor.received.connect ((message) => {
                if (settings.do_not_disturb)
                    return;

                var notification = new Notification.from_message (message);
                var entry = new NotificationEntry (notification);
                nlist.add_item (entry);

                dynamic_icon.set_icon_name ("indicator-messages-new");
            });

            settings.changed["do-not-disturb"].connect (() => {
                main_box.set_size_request (200, 50);
                dynamic_icon.set_icon_name (get_display_icon_name ());
                if (settings.do_not_disturb)
                    stack.set_visible_child (not_disturb_box);
                else
                    nlist.switch_stack (nlist.get_items_length () > 0);    
            });


            main_box.add (stack);
            main_box.pack_end (settings_btn, false, false, 0);
            main_box.pack_end (clear_all_btn, false, false, 0);
            main_box.show ();
            nlist.clear_all ();
        }

        return main_box;
    }

    public override void opened () {
        if (settings.do_not_disturb) {
            stack.set_visible_child (not_disturb_box);
            clear_all_btn.set_visible (false); 
            return;
        }

        nlist.switch_stack (nlist.get_items_length () > 0);
        if (nlist.get_items_length () > 0) 
            clear_all_btn.set_visible (true);
        else
            clear_all_btn.set_visible (false);    
    }

    public override void closed () {

    }

    private string get_display_icon_name () {
        if (settings.do_not_disturb)
            // Use symbolic here
            return "notification-disabled";

        if (nlist.get_items_length () > 0)
            return "indicator-messages-new";

        return "indicator-messages";    
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
    