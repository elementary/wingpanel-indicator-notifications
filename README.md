# Wingpanel Notifications Indicator
[![l10n](https://l10n.elementary.io/widgets/wingpanel/wingpanel-indicator-notifications/svg-badge.svg)](https://l10n.elementary.io/projects/wingpanel/wingpanel-indicator-notifications)

![Screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* libdbus-glib-1-dev
* libgdk-pixbuf2.0-dev
* libglib2.0-dev
* libgranite-dev
* libgtk-3-dev
* libwingpanel-2.0-dev
* libwnck-3-dev
* meson
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
