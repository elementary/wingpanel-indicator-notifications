
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

    private static int get_integer(Variant tuple, int column) {
        Variant child = tuple.get_child_value (column);
        return child.get_int32 ();
    }

    private static bool get_boolean(Variant tuple, int column) {
        Variant child = tuple.get_child_value (column);
        return child.get_boolean ();
    }

    private static uint8 get_byte(Variant tuple, int column) {
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