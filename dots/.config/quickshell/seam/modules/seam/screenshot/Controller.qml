pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "." as Screenshot

Singleton {
    id: root
    property bool isOpen: false
    property string mode: "region"

    function showMode(requestedMode) {
        if (["region", "window", "fullscreen"].indexOf(requestedMode) < 0)
            requestedMode = "region";
        root.mode = requestedMode;
        root.isOpen = true;
    }

    IpcHandler {
        target: "screenshot"

        function open() { root.showMode("region"); }
        function close() { root.isOpen = false; }
        function toggle() { root.isOpen = !root.isOpen; }
        function region() { root.showMode("region"); }
        function window() { root.showMode("window"); }
        function fullscreen() { root.showMode("fullscreen"); }
    }

    LazyLoader {
        active: root.isOpen
        Screenshot.Overlay { controller: root }
    }

    function init() {}
}
