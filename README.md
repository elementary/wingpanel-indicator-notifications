# Wingpanel Notifications Indicator
[![l10n](https://l10n.elementary.io/widgets/wingpanel/wingpanel-indicator-notifications/svg-badge.svg)](https://l10n.elementary.io/projects/wingpanel/wingpanel-indicator-notifications)

## Building and Installation

You'll need the following dependencies:

* cmake
* libdbus-glib-1-dev
* libgdk-pixbuf2.0-dev
* libglib2.0-dev
* libgranite-dev
* libgtk-3-dev
* libwingpanel-2.0-dev
* libwnck-3-dev
* valac

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`

    sudo make install
