
public class Utils : Object {
    public static AppInfo? get_appinfo_from_app_name (string app_name) {
        if (app_name.strip () == "") {
            return null;
        }

        AppInfo? appinfo = null;
        AppInfo.get_all ().@foreach ((_appinfo) => {
            if (_appinfo != null && validate (_appinfo, app_name)) {
                appinfo = _appinfo;
                return;
            }
        });

        return appinfo;
    }

    private static bool validate (AppInfo appinfo, string app_name) {
        string token = app_name.down ().strip ();

        string? token_executable = token;
        if (!token_executable.has_prefix (Path.DIR_SEPARATOR_S)) {
            token_executable = Environment.find_program_in_path (token_executable);
        }        

        string? app_executable = appinfo.get_executable ();
        if (!app_executable.has_prefix (Path.DIR_SEPARATOR_S)) {
            app_executable = Environment.find_program_in_path (app_executable);
        }

        string[] args;
        try {
            Shell.parse_argv (appinfo.get_commandline (), out args);
        } catch (ShellError e) {
            warning ("%s\n", e.message);
        }

        if (appinfo.get_name () != null
        && appinfo.get_executable () != null
        && appinfo.get_display_name () != null) {
            if (appinfo.get_name ().down () == token
                || token_executable == app_executable
                || args[0] == token
                || appinfo.get_display_name ().down ().contains (token))
                return true;
        }            
    
        return false;    
    }
}