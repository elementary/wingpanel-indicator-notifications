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

public class Notifications.Notification : Object {
    public const string DESKTOP_ID_EXT = ".desktop";

    public bool is_transient = false;
    public string app_name;
    public string summary;
    public string message_body;
    public string image_path { get; private set; default = ""; }
    public string app_icon;
    public string sender;
    public string[] actions;
    public uint32 replaces_id;
    public uint32 id;
    public bool has_temp_file;
    public GLib.DateTime timestamp;
    public GLib.Icon badge_icon { get; construct set; }

    public string desktop_id;
    public DesktopAppInfo? app_info = null;

    public signal void closed ();

    private enum Column {
        APP_NAME = 0,
        REPLACES_ID,
        APP_ICON,
        SUMMARY,
        BODY,
        ACTIONS,
        HINTS,
        EXPIRE_TIMEOUT,
        COUNT
    }

    private const string DEFAULT_ACTION = "default";
    private const string X_CANONICAL_PRIVATE_KEY = "x-canonical-private-synchronous";
    private const string DESKTOP_ENTRY_KEY = "desktop-entry";
    private const string FALLBACK_DESKTOP_ID = "gala-other" + DESKTOP_ID_EXT;

    public Notification (
        uint32 _id, string _app_name, string _app_icon, string _summary, string _message_body, string _image_path,
        string[] _actions, string _desktop_id, int64 _unix_time, uint64 _replaces_id, string _sender, bool _has_temp_file
    ) {
        app_name = _app_name;
        app_icon = _app_icon;
        summary = _summary;
        message_body = _message_body;
        image_path = _image_path;
        replaces_id = (uint32) _replaces_id;
        id = _id;
        sender = _sender;

        actions = _actions;
        timestamp = new GLib.DateTime.from_unix_local (_unix_time);

        desktop_id = _desktop_id;
        app_info = new DesktopAppInfo (desktop_id);

        has_temp_file = _has_temp_file;
    }

    public Notification.from_message (DBusMessage message, uint32 _id) {
        var body = message.get_body ();

        app_name = get_string (body, Column.APP_NAME);
        summary = get_string (body, Column.SUMMARY);
        message_body = get_string (body, Column.BODY);
        var hints = body.get_child_value (Column.HINTS);
        replaces_id = get_uint32 (body, Column.REPLACES_ID);
        id = _id;
        sender = message.get_sender ();

        actions = body.get_child_value (Column.ACTIONS).dup_strv ();
        timestamp = new GLib.DateTime.now_local ();

        desktop_id = lookup_string (hints, DESKTOP_ENTRY_KEY);
        if (desktop_id != null && desktop_id != "") {
            if (!desktop_id.has_suffix (DESKTOP_ID_EXT)) {
                desktop_id += DESKTOP_ID_EXT;
            }

            app_info = new DesktopAppInfo (desktop_id);
            if (app_info == null) {
                app_info = new DesktopAppInfo.from_filename ("/etc/xdg/autostart/%s".printf (desktop_id));
            }
        }

        app_icon = get_string (body, Column.APP_ICON);
        if (app_icon == "" && app_info != null) {
            app_icon = app_info.get_icon ().to_string ();
        }

        // GLib.Notification.set_icon ()
        if ((image_path = lookup_string (hints, "image-path")) != "" || (image_path = lookup_string (hints, "image_path")) != "") {
            // Ensure we're not being sent symbolic badge icons
            image_path = image_path.replace ("-symbolic", "");

            // GLib.Notification also sends icon names via this hint
            if (Gtk.IconTheme.get_default ().has_icon (image_path) && image_path != app_icon) {
                badge_icon = new ThemedIcon (image_path);
            }

            var is_a_path = image_path.has_prefix ("/") || image_path.has_prefix ("file://");
            if (badge_icon != null || !is_a_path) {
                image_path = "";
            }
        }

        // Raw image data sent within a variant
        Gdk.Pixbuf? buf = null;
        if ((buf = lookup_pixbuf (hints, "image-data")) != null || (buf = lookup_pixbuf (hints, "image_data")) != null || (buf = lookup_pixbuf (hints, "icon_data")) != null) {
            var tmpfile = store_pixbuf (buf);
            if (tmpfile != null) {
                image_path = tmpfile;
                has_temp_file = true;
            }
        }

        if (app_info == null) {
            desktop_id = FALLBACK_DESKTOP_ID;
            app_info = new DesktopAppInfo (desktop_id);
        }

        var transient_hint = hints.lookup_value ("transient", VariantType.BOOLEAN);
        is_transient = hints.lookup_value (X_CANONICAL_PRIVATE_KEY, null) != null || (transient_hint != null && transient_hint.get_boolean ());
    }

    public void close () {
        closed ();
    }

    public bool run_default_action () {
        if (DEFAULT_ACTION in actions) {
            app_info.launch_action (DEFAULT_ACTION, new GLib.AppLaunchContext ());

            var notifications_iface = NotificationMonitor.get_instance ().notifications_iface;
            if (notifications_iface != null) {
                notifications_iface.action_invoked (id, DEFAULT_ACTION);
            }

            return true;
        } else {
            try {
                app_info.launch (null, null);
            } catch (Error e) {
                critical ("Unable to launch app: %s", e.message);
            }
        }

        return false;
    }

    private string get_string (Variant tuple, int column) {
        var child = tuple.get_child_value (column);
        return child.dup_string ();
    }

    private uint32 get_uint32 (Variant tuple, int column) {
        var child = tuple.get_child_value (column);
        return child.get_uint32 ();
    }

    private string lookup_string (Variant tuple, string key) {
        var child = tuple.lookup_value (key, null);

        if (child == null || !child.is_of_type (VariantType.STRING)) {
            return "";
        }

        return child.dup_string ();
    }

    private Gdk.Pixbuf? lookup_pixbuf (Variant tuple, string key) {
        var img = tuple.lookup_value (key, null);

        if (img == null || img.get_type_string () != "(iiibiiay)") {
            return null;
        }

        int width = img.get_child_value (0).get_int32 ();
        int height = img.get_child_value (1).get_int32 ();
        int rowstride = img.get_child_value (2).get_int32 ();
        bool has_alpha = img.get_child_value (3).get_boolean ();
        int bits_per_sample = img.get_child_value (4).get_int32 ();
        unowned uint8[] raw = (uint8[]) img.get_child_value (6).get_data ();

        // Build the pixbuf from the unowned buffer, and copy it to maintain our own instance.
        Gdk.Pixbuf pixbuf = new Gdk.Pixbuf.with_unowned_data (raw, Gdk.Colorspace.RGB,
            has_alpha, bits_per_sample, width, height, rowstride, null);
        return pixbuf.copy ();
    }

    private string? make_temp_file (string tmpl) {
        FileIOStream iostream;
        try {
            File file = File.new_tmp (tmpl, out iostream);
            return file.get_path ();
        } catch (Error e) {
            return null;
        }
    }

    public string? store_pixbuf (Gdk.Pixbuf pixbuf) {
        string? tmpfile = make_temp_file ("wingpanel-XXXXXX.png");
        if (tmpfile != null) {
            try {
                if (pixbuf.save (tmpfile, "png", null)) {
                    return tmpfile;
                }
            } catch (Error e) {
                critical ("Unable to cache image: %s", e.message);
                var file = File.new_for_path (tmpfile);
                try {
                    file.delete ();
                } catch (Error e) {
                    critical ("Unable to delete tmpfile: %s", tmpfile);
                }
            }
        }
        return null;
    }
}
