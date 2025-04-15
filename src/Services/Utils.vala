/*
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

namespace Notifications.Utils {
    public static Variant? maybe_from_array (Variant[] array) {
        if (array.length == 0) {
            return null;
        }

        return array[0];
    }
}
