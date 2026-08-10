pragma Singleton

import QtQuick
import qs.modules.common

QtObject {
    readonly property int thickness: 10
    readonly property int cornerRadius: Appearance.radius(24)
    readonly property color color: Appearance.colors.colLayer0
    readonly property color outerCornerColor: "#000000"
}
