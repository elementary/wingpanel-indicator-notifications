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


/* This class is meant to remember the
 * notifications from the current session
 * and restore them in the next session.
 *
 * KeyFile does not support getting
 * uint32 values so we need
 * to store id's in uint64 variables.
 */
public class Session : GLib.Object {
    private const string SESSION_NAME_FILE = "/.notifications.session";
    private static File? session_file = null;
    private static string full_path;
    
    private const string APP_NAME_KEY = "AppName";
    private const string APP_ICON_KEY = "AppIcon";
    private const string SUMMARY_KEY = "Summary";
    private const string BODY_KEY = "Body";
    private const string ACTIONS_KEY = "Actions";
    private const string UNIX_TIME_KEY = "UnixTime";
    private const string SENDER_KEY = "Sender";

    private KeyFile key;

    public Session () {
        full_path = Environment.get_user_cache_dir () + SESSION_NAME_FILE;
        session_file = File.new_for_path (full_path);
        if (!session_file.query_exists ())
            create_session_file ();

        key = new KeyFile ();
        key.set_list_separator (',');
    }

    public List<Notification> get_session_notifications () {
        var list = new List<Notification> ();
        var _key = new KeyFile ();
        try {
            _key.load_from_file (full_path, KeyFileFlags.NONE);
            foreach (unowned string group in _key.get_groups ()) {
                var notification = new Notification.from_data (uint64.parse (group),
                                                            _key.get_string (group, APP_NAME_KEY),
                                                            _key.get_string (group, APP_ICON_KEY),
                                                            _key.get_string (group, SUMMARY_KEY),
                                                            _key.get_string (group, BODY_KEY),
                                                            _key.get_string_list (group, ACTIONS_KEY),
                                                            _key.get_int64 (group, UNIX_TIME_KEY),
                                                            _key.get_string (group, SENDER_KEY));
                list.append (notification);
            }
        } catch (KeyFileError e) {
            warning (e.message);
        } catch (FileError e) {
            warning (e.message);
        }

        return list;
    }

    public void add_notification (Notification notification) {
        string id = this.get_notification_id (notification);
        key.set_string (id, APP_NAME_KEY, notification.app_name);
        key.set_string (id, APP_ICON_KEY, notification.app_icon);
        key.set_string (id, SUMMARY_KEY, notification.summary);
        key.set_string (id, BODY_KEY, notification.message_body);
        key.set_string_list (id, ACTIONS_KEY, notification.actions);
        key.set_int64 (id, UNIX_TIME_KEY, notification.unix_time);
        key.set_string (id, SENDER_KEY, notification.sender);

        write_contents ();
    }

    public void remove_notification (Notification notification) {
        try {
            key.remove_group (this.get_notification_id (notification));
        } catch (KeyFileError e) {
            warning (e.message);
        }

        write_contents ();
    }

    public void clear () {
        try {
            key = new KeyFile ();
            FileUtils.set_contents (session_file.get_path (), "");
        } catch (FileError e) {
            warning (e.message);
        }
    }

    private void create_session_file () {
        try {
            session_file.create (FileCreateFlags.REPLACE_DESTINATION);
        } catch (Error e) {
            warning (e.message);
        }
    }

    private string get_notification_id (Notification notification) {
        string id;
        if (notification.id == -1)
            id = notification.id_64.to_string ();
        else
            id = notification.id.to_string ();

        return id;
    }

    private void write_contents () {
        if (session_file == null)
            create_session_file ();

        try {
            FileUtils.set_contents (session_file.get_path (), key.to_data ());
        } catch (FileError e) {
            warning (e.message);
        }
    }
}
