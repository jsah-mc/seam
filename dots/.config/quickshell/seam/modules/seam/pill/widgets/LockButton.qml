import Quickshell
import QtQuick
import qs.modules.common

Rectangle {
    FontLoader {
        id: materialIcons
        source: "file:///usr/share/fonts/ttf-material-symbols-variable/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
    }
    width: 22
    height: 22
    radius: Appearance.radius(height / 2)
    color: hover.hovered ? Appearance.m3colors.m3primaryContainer : Appearance.m3colors.m3surfaceContainerHigh
    scale: hover.hovered ? 1.08 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Text {
        anchors.centerIn: parent
        text: "lock"
        color: Appearance.m3colors.m3onSurface
        font.family: materialIcons.name
        font.pixelSize: 13
    }
    HoverHandler { id: hover }
    TapHandler {
        onTapped: Quickshell.execDetached(["qs", "ipc", "-c", "seam", "call", "lock", "activate"])
    }
}
