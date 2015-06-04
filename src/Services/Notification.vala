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

public class Notification : Object {
    public string app_name;
    public string summary;
    public string message_body;
    public string icon;
    public Gdk.Pixbuf? icon_pixbuf;

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

    private static string get_string (Variant tuple, int column) {
        Variant child = tuple.get_child_value (column);
        return child.dup_string ();
    }

    private static int get_integer (Variant tuple, int column) {
        Variant child = tuple.get_child_value (column);
        return child.get_int32 ();
    }

    private static bool get_boolean (Variant tuple, int column) {
        Variant child = tuple.get_child_value (column);
        return child.get_boolean ();
    }

    private static uint8 get_byte (Variant tuple, int column) {
        Variant child = tuple.get_child_value (column);
        return child.get_byte ();
    }
    
    public Notification.from_message (DBusMessage message) {
        var body = message.get_body ();

        this.app_name = this.get_string (body, Column.APP_NAME);
        this.icon = this.get_string (body, Column.APP_ICON);
        this.summary = this.get_string (body, Column.SUMMARY);
        this.message_body = this.get_string (body, Column.BODY);
    }
}