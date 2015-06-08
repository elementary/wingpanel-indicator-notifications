
public class Utils : Object {
    public static AppInfo? get_appinfo_from_app_name (string app_name) {
        AppInfo? appinfo = null;
        AppInfo.get_all ().@foreach ((_appinfo) => {
            if (_appinfo.get_name () == app_name)
                appinfo = _appinfo;
        });

        return appinfo;
    }
}