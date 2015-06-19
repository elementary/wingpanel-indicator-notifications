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
    private static KeyFile key;
    private static string full_path;

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
                                                            _key.get_string (group, "AppName"),
                                                            _key.get_string (group,"AppIcon"),
                                                            _key.get_string (group, "Summary"),
                                                            _key.get_string (group, "Body"),
                                                            _key.get_string_list (group, "Actions"),
                                                            _key.get_string (group, "Sender"));
                list.append (notification);
            }
        } catch (KeyFileError e) {
            warning ("%s\n", e.message);
        } catch (FileError e) {
            warning ("%s\n", e.message);
        } 

        return list;
    }

    public void add_notification (Notification notification) {
        string id = this.get_notification_id (notification);
        key.set_string (id, "AppName", notification.app_name);
        key.set_string (id, "AppIcon", notification.app_icon);
        key.set_string (id, "Summary", notification.summary);
        key.set_string (id, "Body", notification.message_body);
        key.set_string_list (id, "Actions", notification.actions);
        key.set_string (id, "Sender", notification.sender);

        write_contents ();
    }

    public void remove_notification (Notification notification) {
        try {
            key.remove_group (this.get_notification_id (notification));
        } catch (KeyFileError e) {
            warning ("%s\n", e.message);
        }

        write_contents ();
    }

    public void clear () {  
        try {      
        FileUtils.set_contents (session_file.get_path (), ""); 
        } catch (FileError e) {
            warning ("%s\n", e.message);
        }
    }

    private void create_session_file () {
        try {
            session_file.create (FileCreateFlags.REPLACE_DESTINATION);
        } catch (Error e) {
            warning ("%s\n", e.message);
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
            warning ("%s\n", e.message);
        }          
    }    
}
