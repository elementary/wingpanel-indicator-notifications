
public class Utils : Object {
    public static AppInfo? get_appinfo_from_app_name (string app_name) {
        AppInfo? appinfo = null;
        AppInfo.get_all ().@foreach ((_appinfo) => {
            if (_appinfo.get_name ().down () == app_name.down ()
                || app_name.down ().contains (_appinfo.get_executable ().down ())
                || _appinfo.get_display_name ().down ().contains (app_name.down ()))
                appinfo = _appinfo;
        });

        return appinfo;
    }
}