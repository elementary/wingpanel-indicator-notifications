/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

/**
 * Sorts the notifications from the provider in sections of apps and
 * by timestamp.
 */
public class Notifications.NotificationModel : Object, ListModel {
    public ListModel model { get; construct; }

    public uint n_notifications { get { return sorting.size; } }
    public uint n_apps { get; private set; default = 0; }

    private Gee.List<uint> sorting;

    public NotificationModel (NotificationProvider provider) {
        Object (model: provider.notifications);
    }

    construct {
        sorting = new Gee.UnrolledLinkedList<uint> ();

        model.items_changed.connect (on_items_changed);
        warning (model.get_n_items ().to_string ());
        on_items_changed (0, 0, model.get_n_items ());
    }

    /**
     * Keep our sorting up to date. We have fast paths for the most common
     * cases (notification added, notification removed, notification replaced).
     * Other cases should pretty much never happen, but we handle them anyway.
     */
    private void on_items_changed (uint pos, uint removed, uint added) {
        if (removed == 0 && added == 0) { // No change
            return;
        }

        if (added == 0 && removed == 1) { // Notification dismissed
            var removal_pos = sorting.index_of (pos);
            sorting.remove (pos);

            shift (pos, -1);

            items_changed (removal_pos, 1, 0);
        } else if (added == 1 && removed == 0) { // Notification added
            shift (pos, 1);

            var notification = (Notification) model.get_item (pos);
            var app_id = notification.app_id;

            var section_iter = sorting.filter ((i) => {
                return ((Notification) model.get_item (i)).app_id == app_id;
            });

            var section = new Gee.LinkedList<uint> ();
            section.add_all_iterator (section_iter);

            if (section.size > 0) {
                var removal_pos = sorting.index_of (section.first ());
                sorting.remove_all (section);

                items_changed (removal_pos, section.size, 0);
            }

            section.insert (0, pos);

            sorting.insert_all (0, section);

            items_changed (0, 0, section.size);
        } else if (added == 1 && removed == 1) { // Notification replaced (without SHOW_AS_NEW)
            var change_pos = sorting.index_of (pos);
            items_changed (change_pos, 1, 1);
        } else { // This shouldn't happen (except on first start)
            var array_list = new Gee.ArrayList<uint> ();

            for (uint i = 0; i < model.get_n_items (); i++) {
                array_list.add (i);
            }

            array_list.sort ((a, b) => {
                var notification_a = (Notification) model.get_item (a);
                var notification_b = (Notification) model.get_item (b);

                return notification_b.compare (notification_a);
            });

            sorting.clear ();
            sorting.add_all (array_list);

            items_changed (0, sorting.size - (added - removed), sorting.size);
        }

        notify_property ("n-notifications");
    }

    private void shift (uint from, uint by) {
        var iter = sorting.list_iterator ();
        while (iter.next ()) {
            var current_pos = iter.get ();
            if (current_pos >= from) {
                iter.set (current_pos + by);
            }
        }
    }

    public Object? get_item (uint pos) {
        return model.get_item (sorting[(int) pos]);
    }

    public uint get_n_items () {
        return n_notifications;
    }

    public Type get_item_type () {
        return typeof (Notification);
    }
}
