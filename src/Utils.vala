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

public class Utils : Object {
    private static Gee.HashMap<string, AppInfo> app_info_cache;

    public static void init () {
        app_info_cache = new Gee.HashMap<string, AppInfo> ();
    }

    public static AppInfo? get_appinfo_from_app_name (string app_name) {
        if (app_name.strip () == "") {
            return null;
        }

        AppInfo? app_info = app_info_cache.get (app_name);
        foreach (unowned AppInfo info in AppInfo.get_all ()) {
            if (info == null || !validate (info, app_name)) {
                continue;
            }

            app_info = info;
            break;
        }

        app_info_cache.set (app_name, app_info);
        return app_info;
    }

    private static bool validate (AppInfo appinfo, string name) {
       string? app_executable = appinfo.get_executable ();
       string? app_name = appinfo.get_name ();
       string? app_display_name = appinfo.get_display_name ();

       if (app_name == null || app_executable == null || app_display_name == null) {
           return false;
       }

       string token = name.down ().strip ();
       string? token_executable = token;
       if (!token_executable.has_prefix (Path.DIR_SEPARATOR_S)) {
           token_executable = Environment.find_program_in_path (token_executable);
       }

       if (!app_executable.has_prefix (Path.DIR_SEPARATOR_S)) {
           app_executable = Environment.find_program_in_path (app_executable);
       }

       string[] args;

       try {
           Shell.parse_argv (appinfo.get_commandline (), out args);
       } catch (ShellError e) {
           warning ("%s", e.message);
       }

       return (app_name.down () == token
           || token_executable == app_executable
           || args[0] == token
           || app_display_name.down ().contains (token));
    }
}