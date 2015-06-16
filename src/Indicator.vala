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

/* Reflects current state of popover.
 * Used to inform the time_label to
 * not change when the popover is shown.
 */
public bool indicator_opened = false;

/* Notiifcations monitor */
public NotificationMonitor monitor;

public NSettings settings;

public class Indicator : Wingpanel.Indicator {
    private const string SETTINGS_EXEC = "switchboard notifications";
    private const uint16 BOX_WIDTH = 300;
    private const uint16 BOX_HEIGHT = 400;
    private const string[] EXCEPTIONS = { "", "indicator-sound", "NetworkManager", "gnome-settings-daemon" };

    private Wingpanel.Widgets.DynamicIcon? dynamic_icon = null;
    private Gtk.Box? main_box = null;
    private Wingpanel.Widgets.IndicatorButton clear_all_btn;
    private Gtk.Stack stack;

    private NotificationsList nlist;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.MESSAGES,
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

            var no_notifications_label = new Gtk.Label (_("No Notifications"));
            no_notifications_label.get_style_context ().add_class ("h2");
            no_notifications_label.sensitive = false;
            no_notifications_label.margin_top = no_notifications_label.margin_bottom = 50;

            nlist = new NotificationsList ();

            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.add (nlist);

            stack.add_named (scrolled, "list");
            stack.add_named (no_notifications_label, "no-notifications");

            var not_disturb_switch = new Wingpanel.Widgets.IndicatorSwitch (_("Do Not Disturb"), settings.do_not_disturb);
            not_disturb_switch.get_label ().get_style_context ().add_class ("h4");
            not_disturb_switch.get_switch ().notify["active"].connect (() => { 
                settings.do_not_disturb = not_disturb_switch.get_switch ().active;
            });

            clear_all_btn = new Wingpanel.Widgets.IndicatorButton (_("Clear All Notifications"));
            clear_all_btn.clicked.connect (nlist.clear_all);

            var settings_btn = new Wingpanel.Widgets.IndicatorButton (_("Notifications Settings…"));
            settings_btn.clicked.connect (show_settings);

            nlist.close_popover.connect (() => {
                this.close ();
            });

            nlist.switch_stack.connect ((list) => {
                if (list) {
                    main_box.set_size_request (BOX_WIDTH, BOX_HEIGHT);
                    stack.set_visible_child_name ("list");
                    clear_all_btn.set_visible (true);
                } else {
                    main_box.set_size_request (BOX_WIDTH, -1);
                    stack.set_visible_child_name ("no-notifications");
                    dynamic_icon.set_icon_name ("indicator-messages");
                    clear_all_btn.set_visible (false);
                }
            });

            monitor.received.connect ((message, id) => {
                var notification = new Notification.from_message (message, id);
                if (notification.app_name in EXCEPTIONS)
                    return;

                var entry = new NotificationEntry (notification);
                nlist.add_item (entry);

                dynamic_icon.set_icon_name (get_display_icon_name ());
            });

            settings.changed["do-not-disturb"].connect (() => {
                not_disturb_switch.get_switch ().active = settings.do_not_disturb;
                dynamic_icon.set_icon_name (get_display_icon_name ());
            });

            main_box.add (not_disturb_switch);
            main_box.add (new Wingpanel.Widgets.IndicatorSeparator ());
            main_box.add (stack);
            main_box.add (new Wingpanel.Widgets.IndicatorSeparator ());
            main_box.pack_end (settings_btn, false, false, 0);
            main_box.pack_end (clear_all_btn, false, false, 0);
            main_box.show_all ();

            nlist.clear_all ();
            dynamic_icon.set_icon_name (get_display_icon_name ());
        }

        return main_box;
    }

    public override void opened () {  
        indicator_opened = true;

        nlist.switch_stack (nlist.get_items_length () > 0);
        if (nlist.get_items_length () > 0) 
            clear_all_btn.visible = true;
        else
            clear_all_btn.visible = false;    
    }

    public override void closed () {
        indicator_opened = false;
    }

    private string get_display_icon_name () {
        if (settings.do_not_disturb)
            return "notification-disabled-symbolic";
        else if (nlist.get_items_length () > 0)
            return "indicator-messages-new";
        else
            return "notification-symbolic";    
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
    
