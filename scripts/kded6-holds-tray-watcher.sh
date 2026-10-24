#!/usr/bin/env bash
# Exit 0 when kded6 owns org.kde.StatusNotifierWatcher, which keeps the shell's
# own tray watcher from registering. kded6 merely running is not a conflict:
# any KDE app can start it over D-Bus, and once the shell holds the name a new
# kded6 cannot take it.
pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
    GetConnectionUnixProcessID s org.kde.StatusNotifierWatcher 2>/dev/null | awk '{print $2}')
[ -n "$pid" ] && [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = kded6 ]
