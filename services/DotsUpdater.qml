pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "yay -Syu --combinedupgrade=false"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    // Disabled: upstream's updater deletes ~/.config/quickshell/end4-pC and
    // re-clones pctrade/end4-pC, which would discard this fork's changes.
    function runUpdateDots() {
        Quickshell.execDetached(["notify-send", "Update Dots", "Disabled to preserve custom configuration.", "-a", "Settings"])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }
}
