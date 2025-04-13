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

public class Notifications.NotificationEntry : Granite.Bin {
    private const int ICON_SIZE_PRIMARY = 48;
    private const int ICON_SIZE_SECONDARY = 24;

    private static Gtk.CssProvider provider;
    private static Regex entity_regex;
    private static Regex tag_regex;

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

    private Adw.Carousel carousel;
    private Gtk.Overlay overlay;

    private Gtk.Image primary_image;
    private Gtk.Label title_label;
    private Gtk.Label body_label;
    private Gtk.Label time_label;
    private Gtk.Button delete_button;
    private Gtk.FlowBox flow_box;
    private Gtk.Revealer revealer;

    private Notification? notification;
    private Binding? collapsed_binding;
    private uint timeout_id;

    construct {
        primary_image = new Gtk.Image () {
            pixel_size = ICON_SIZE_PRIMARY
        };

        var image_overlay = new Gtk.Overlay () {
            child = primary_image,
            valign = START
        };

        title_label = new Gtk.Label (null) {
            ellipsize = Pango.EllipsizeMode.END,
            hexpand = true,
            width_chars = 27,
            max_width_chars = 27,
            use_markup = true,
            xalign = 0
        };

        time_label = new Gtk.Label ("TIME TODO") {
            margin_end = 6
        };
        time_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var grid = new Gtk.Grid () {
            hexpand = true,
            column_spacing = 6,
            margin_start = 12,
            margin_end = 12,
            // Box shadow is clipped to the margin area
            margin_top = 9,
            margin_bottom = 9
        };

        unowned Gtk.StyleContext grid_context = grid.get_style_context ();
        grid_context.add_class (Granite.STYLE_CLASS_CARD);
        grid_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var delete_image = new Gtk.Image.from_icon_name ("window-close-symbolic");
        delete_image.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        delete_button = new Gtk.Button () {
            halign = Gtk.Align.START,
            valign = Gtk.Align.START,
            child = delete_image,
        };
        delete_button.get_style_context ().add_class ("close");
        delete_button.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var delete_revealer = new Gtk.Revealer () {
            halign = Gtk.Align.START,
            valign = Gtk.Align.START,
            reveal_child = false,
            transition_duration = Granite.TRANSITION_DURATION_CLOSE,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE,
            child = delete_button
        };

        grid.attach (image_overlay, 0, 0, 1, 2);
        grid.attach (title_label, 1, 0);
        grid.attach (time_label, 2, 0);

        body_label = new Gtk.Label (null) {
            ellipsize = Pango.EllipsizeMode.END,
            lines = 2,
            use_markup = true,
            valign = Gtk.Align.START,
            wrap_mode = Pango.WrapMode.WORD_CHAR,
            wrap = true,
            xalign = 0
        };

        grid.attach (body_label, 1, 1, 2);

        flow_box = new Gtk.FlowBox () {
            margin_top = 12,
            halign = Gtk.Align.END,
            homogeneous = true
        };

        grid.attach (flow_box, 0, 2, 3);

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

        overlay = new Gtk.Overlay () {
            child = grid
        };
        overlay.add_overlay (delete_revealer);

        carousel = new Adw.Carousel () {
            hexpand = true,
            halign = CENTER
        };
        carousel.append (delete_left);
        carousel.append (overlay);
        carousel.append (delete_right);

        revealer = new Gtk.Revealer () {
            reveal_child = true,
            transition_duration = NotificationManager.REMOVAL_ANIMATION,
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP,
            child = carousel
        };

        child = revealer;

        var motion_controller = new Gtk.EventControllerMotion ();
        motion_controller.bind_property ("contains-pointer", delete_revealer, "reveal-child", SYNC_CREATE);
        add_controller (motion_controller);

        //  carousel.page_changed.connect (on_page_changed);
    }

    //TODO
    private void on_page_changed (uint index) {
        if (notification != null && index != 2) {
            activate_action_variant (NotificationsList.ACTION_PREFIX + notification.dismiss_action_name, null);
        }
    }

    public void bind (Notification notification) {
        carousel.scroll_to (overlay, false);

        this.notification = notification;

        primary_image.gicon = notification.primary_icon;

        title_label.label = notification.title;
        body_label.label = fix_markup (notification.body);

        time_label.label = Granite.DateTime.get_relative_datetime (notification.timestamp);
        timeout_id = Timeout.add_seconds (60, update_time_label);

        delete_button.action_name = NotificationsList.ACTION_PREFIX + notification.dismiss_action_name;

        flow_box.bind_model (notification.buttons, create_button);

        collapsed_binding = notification.bind_property ("collapsed", revealer, "reveal-child", SYNC_CREATE | INVERT_BOOLEAN);
    }

    private bool update_time_label () {
        time_label.label = Granite.DateTime.get_relative_datetime (notification.timestamp);
        return Source.CONTINUE;
    }

    private Gtk.Widget create_button (Object object) {
        var button = (Button) object;
        return new Gtk.Button.with_label (button.label) {
            action_name = button.action_name,
            action_target = button.action_target
        };
    }

    public void unbind () {
        notification = null;
        collapsed_binding.unbind ();
        collapsed_binding = null;
        Source.remove (timeout_id);
    }

    private class DeleteAffordance : Granite.Bin {
        public Gtk.Align alignment { get; construct; }

        public DeleteAffordance (Gtk.Align alignment) {
            Object (alignment: alignment);
        }

        construct {
            var image = new Gtk.Image.from_icon_name ("edit-delete-symbolic");
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

            child = delete_internal_grid;

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
