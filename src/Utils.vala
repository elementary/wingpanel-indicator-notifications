
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

        if (appinfo.get_name () != null
        && appinfo.get_executable () != null
        && appinfo.get_display_name () != null) {
            if (appinfo.get_name ().down () == token
                || appinfo.get_executable ().down () == token
                || appinfo.get_display_name ().down ().contains (token))
                return true;
        }            
    
        return false;    
    }
}