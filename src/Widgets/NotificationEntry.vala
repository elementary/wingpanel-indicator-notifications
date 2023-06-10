/*-
 * Copyright (c) 2015-2018 elementary LLC. (https://elementary.io)
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

public class Notifications.NotificationEntry : Gtk.ListBoxRow {
    public signal void clear ();

    public Notification notification { get; construct; }

    private Gtk.Revealer revealer;
    private uint timeout_id;

    private const int ICON_SIZE_PRIMARY = 48;
    private const int ICON_SIZE_SECONDARY = 24;

    private static Gtk.CssProvider provider;
    private static Regex entity_regex;
    private static Regex tag_regex;

    public NotificationEntry (Notification notification) {
        Object (notification: notification);
    }

    static construct {
        provider = new Gtk.CssProvider ();
        provider.load_from_resource ("io/elementary/wingpanel/notifications/NotificationEntry.css");

        try {
            entity_regex = new Regex ("&(?!amp;|quot;|apos;|lt;|gt;|nbsp;|#39)");
            tag_regex = new Regex ("<(?!\\/?[biu]>)");
        } catch (Error e) {
            warning ("Invalid regex: %s", e.message);
        }
    }

    construct {
        var app_image = new Gtk.Image ();

        if (notification.app_icon.contains ("/")) {
            var file = File.new_for_uri (notification.app_icon);
            if (file.query_exists ()) {
                app_image.gicon = new FileIcon (file);
            } else {
                app_image.icon_name = "dialog-information";
            }
        } else {
            app_image.icon_name = notification.app_icon;
        }

        var image_overlay = new Gtk.Overlay ();
        image_overlay.valign = Gtk.Align.START;

        if (notification.image_path != null && notification.image_path != "") {
            try {
                var scale = get_style_context ().get_scale ();
                var pixbuf = new Gdk.Pixbuf.from_file_at_size (notification.image_path, ICON_SIZE_PRIMARY * scale, ICON_SIZE_PRIMARY * scale);

                var masked_image = new Notifications.MaskedImage (pixbuf);

                app_image.pixel_size = ICON_SIZE_SECONDARY;
                app_image.halign = app_image.valign = Gtk.Align.END;

                image_overlay.add (masked_image);
                image_overlay.add_overlay (app_image);
            } catch (Error e) {
                critical ("Unable to mask image: %s", e.message);

                app_image.pixel_size = ICON_SIZE_PRIMARY;
                image_overlay.add (app_image);
            }
        } else {
            app_image.pixel_size = ICON_SIZE_PRIMARY;
            image_overlay.add (app_image);

            if (notification.badge_icon != null) {
                var badge_image = new Gtk.Image.from_gicon (notification.badge_icon, Gtk.IconSize.LARGE_TOOLBAR) {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.END,
                    pixel_size = ICON_SIZE_SECONDARY
                };
                image_overlay.add_overlay (badge_image);
            }
        }

        var entry_title = notification.summary;

        if (notification.message_body == "") {
            if (notification.app_name == "" && notification.app_info != null) {
                notification.app_name = notification.app_info.get_display_name ();
            }

            entry_title = notification.app_name;
        }

        var title_label = new Gtk.Label ("<b>%s</b>".printf (fix_markup (entry_title))) {
            ellipsize = Pango.EllipsizeMode.END,
            hexpand = true,
            width_chars = 27,
            max_width_chars = 27,
            use_markup = true,
            xalign = 0
        };

        var time_label = new Gtk.Label (Granite.DateTime.get_relative_datetime (notification.timestamp)) {
            margin_end = 6
        };
        time_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var grid = new Gtk.Grid () {
            hexpand = true,
            column_spacing = 6,
            margin = 12,
            // Box shadow is clipped to the margin area
            margin_top = 9,
            margin_bottom = 9
        };

        unowned Gtk.StyleContext grid_context = grid.get_style_context ();
        grid_context.add_class (Granite.STYLE_CLASS_CARD);
        grid_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var delete_image = new Gtk.Image.from_icon_name ("window-close-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        delete_image.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var delete_button = new Gtk.Button () {
            halign = Gtk.Align.START,
            valign = Gtk.Align.START,
            image = delete_image
        };
        delete_button.get_style_context ().add_class ("close");
        delete_button.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var delete_revealer = new Gtk.Revealer () {
            halign = Gtk.Align.START,
            valign = Gtk.Align.START,
            reveal_child = false,
            transition_duration = Granite.TRANSITION_DURATION_CLOSE,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        delete_revealer.add (delete_button);

        grid.attach (image_overlay, 0, 0, 1, 2);
        grid.attach (title_label, 1, 0);
        grid.attach (time_label, 2, 0);

        var entry_body = notification.message_body;

        if (entry_body == "") {
            entry_body = notification.summary;
        }

        var body = fix_markup (entry_body);

        var body_label = new Gtk.Label (body) {
            ellipsize = Pango.EllipsizeMode.END,
            lines = 2,
            use_markup = true,
            valign = Gtk.Align.START,
            wrap_mode = Pango.WrapMode.WORD_CHAR,
            wrap = true,
            xalign = 0
        };

        if ("\n" in body) {
            string[] lines = body.split ("\n");
            string stripped_body = lines[0] + "\n";
            for (int i = 1; i < lines.length; i++) {
                stripped_body += lines[i].strip () + " ";
            }

            body_label.label = stripped_body.strip ();
            body_label.lines = 1;

        }

        grid.attach (body_label, 1, 1, 2);

        if (notification.actions.length > 0) {
            var action_area = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_top = 12,
                halign = Gtk.Align.END,
                homogeneous = true
            };

            bool action_area_packed = false;

            for (int i = 0; i < notification.actions.length; i += 2) {
                if (notification.actions[i] == Notification.DEFAULT_ACTION) {
                    i += 2; //TODO: The i += 2 is copied from elementary/notifications. No idea why that's there though?
                    continue;
                }

                var button = new Gtk.Button.with_label (notification.actions[i + 1]);
                var action = notification.actions[i].dup ();

                button.clicked.connect (() => {
                    if (notification.action_invoked (action)) {
                        activate ();
                        clear ();
                    }
                });

                action_area.pack_end (button);

                if (!action_area_packed) {
                    grid.attach (action_area, 0, 2, 3);
                    action_area_packed = true;
                }
            }
        }

        var delete_left = new DeleteAffordance (Gtk.Align.END) {
            // Have to match with the grid
            margin_top = 9,
            margin_bottom = 9
        };
        delete_left.get_style_context ().add_class ("left");

        var delete_right = new DeleteAffordance (Gtk.Align.START) {
            // Have to match with the grid
            margin_top = 9,
            margin_bottom = 9
        };
        delete_right.get_style_context ().add_class ("right");

        var overlay = new Gtk.Overlay ();
        overlay.add (grid);
        overlay.add_overlay (delete_revealer);

        var deck = new Hdy.Deck () {
            can_swipe_back = true,
            can_swipe_forward = true,
            transition_type = Hdy.DeckTransitionType.SLIDE
        };
        deck.add (delete_left);
        deck.add (overlay);
        deck.add (delete_right);
        deck.visible_child = overlay;

        revealer = new Gtk.Revealer () {
            reveal_child = true,
            transition_duration = 200,
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP
        };
        revealer.add (deck);

        var eventbox = new Gtk.EventBox ();
        eventbox.events |= Gdk.EventMask.ENTER_NOTIFY_MASK &
                           Gdk.EventMask.LEAVE_NOTIFY_MASK;

        eventbox.add (revealer);

        add (eventbox);

        show_all ();

        button_release_event.connect (() => {
            if (notification.action_invoked (Notification.DEFAULT_ACTION)) {
                activate ();
                clear ();
            }

            return Gdk.EVENT_STOP;
        });

        delete_button.clicked.connect (() => {
            clear ();
        });

        eventbox.enter_notify_event.connect ((event) => {
            delete_revealer.reveal_child = true;
            return Gdk.EVENT_STOP;
        });

        eventbox.leave_notify_event.connect ((event) => {
            delete_revealer.reveal_child = false;
            return Gdk.EVENT_STOP;
        });

        timeout_id = Timeout.add_seconds_full (Priority.DEFAULT, 60, () => {
            time_label.label = Granite.DateTime.get_relative_datetime (notification.timestamp);
            return GLib.Source.CONTINUE;
        });

        notification.closed.connect (() => clear ());

        deck.notify["visible-child"].connect (() => {
            if (deck.transition_running == false && deck.visible_child != overlay) {
                clear ();
            }
        });

        deck.notify["transition-running"].connect (() => {
            if (deck.transition_running == false && deck.visible_child != overlay) {
                clear ();
            }
        });
    }

    public void dismiss () {
        Source.remove (timeout_id);

        revealer.notify["child-revealed"].connect (() => {
            if (!revealer.child_revealed) {
                destroy ();
            }
        });
        revealer.reveal_child = false;
    }

    private class DeleteAffordance : Gtk.Grid {
        public Gtk.Align alignment { get; construct; }

        public DeleteAffordance (Gtk.Align alignment) {
            Object (alignment: alignment);
        }

        construct {
            var image = new Gtk.Image.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU);
            image.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var label = new Gtk.Label ("<small>%s</small>".printf (_("Delete"))) {
                use_markup = true
            };
            label.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var delete_internal_grid = new Gtk.Grid () {
                halign = alignment,
                hexpand = true,
                row_spacing = 3,
                valign = Gtk.Align.CENTER,
                vexpand = true
            };
            delete_internal_grid.attach (image, 0, 0);
            delete_internal_grid.attach (label, 0, 1);

            add (delete_internal_grid);

            unowned Gtk.StyleContext context = get_style_context ();
            context.add_class ("delete-affordance");
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
    }

    /**
     * Copied from gnome-shell, fixes the mess of markup that is sent to us
     */
    private string fix_markup (string markup) {
        var text = markup;

        try {
            text = entity_regex.replace (markup, markup.length, 0, "&amp;");
            text = tag_regex.replace (text, text.length, 0, "&lt;");
        } catch (Error e) {
            warning ("Invalid regex: %s", e.message);
        }

        return text;
    }
}
