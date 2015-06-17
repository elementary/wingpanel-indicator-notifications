find_package (PkgConfig)

# Add all your dependencies to the list below
pkg_check_modules (DEPS REQUIRED wingpanel-2.0 granite gio-2.0 gdk-pixbuf-2.0 libwnck-3.0)

add_definitions (${DEPS_CFLAGS})
add_definitions (-DWNCK_I_KNOW_THIS_IS_UNSTABLE)
link_directories (${DEPS_LIBRARY_DIRS})

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.22.0" MINIMUM)

include (ValaPrecompile)
# Add all your vala files and requires packages to the List below to include them in the build
vala_precompile (VALA_C ${CMAKE_PROJECT_NAME}
  Indicator.vala
  Utils.vala
  Widgets/NotificationsList.vala
  Widgets/NotificationEntry.vala
  Widgets/AppEntry.vala
  Services/NotificationsMonitor.vala
  Services/Notification.vala
  Services/NSettings.vala
  Services/Settings.vala
  ${CMAKE_CURRENT_BINARY_DIR}/config.vala
PACKAGES
  wingpanel-2.0
  gio-2.0
  granite
  libwnck-3.0
OPTIONS
  --thread
)

add_library (${CMAKE_PROJECT_NAME} MODULE ${VALA_C})
target_link_libraries (${CMAKE_PROJECT_NAME} ${DEPS_LIBRARIES})

# Installation
install (TARGETS ${CMAKE_PROJECT_NAME} DESTINATION ${PKGDATADIR})
