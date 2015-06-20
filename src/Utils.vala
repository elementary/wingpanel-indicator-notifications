
public class Utils : Object {
    public static AppInfo? get_appinfo_from_app_name (string app_name) {
        AppInfo? appinfo = null;
            AppInfo.get_all ().@foreach ((_appinfo) => {
                if (_appinfo != null) {
                    if (validate (_appinfo, app_name))
                        appinfo = _appinfo;
                }
            });

        return appinfo;
    }

    private static bool validate (AppInfo appinfo, string app_name) {
        if (appinfo.get_name () != null
        && appinfo.get_executable () != null
        && appinfo.get_display_name () != null) {
            if (appinfo.get_name ().down () == app_name.down ()
                || app_name.down ().contains (appinfo.get_executable ().down ())
                || appinfo.get_display_name ().down ().contains (app_name.down ()))
                return true;
        }            
    
        return false;    
    }
}