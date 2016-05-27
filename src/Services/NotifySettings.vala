/*-
 * Copyright (c) 2016 Wingpanel Developers (http://launchpad.net/wingpanel)
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

public class NotifySettings : Granite.Services.Settings {
    public static const string DO_NOT_DISTURB_KEY = "do-not-disturb";
    public static NotifySettings? instance = null;

    public bool do_not_disturb { get; set; }

    public static unowned NotifySettings get_instance () {
        if (instance == null) {
            instance = new NotifySettings ();
        }

        return instance;
    }

    private NotifySettings () {
        base ("org.pantheon.desktop.gala.notifications");
    }
}