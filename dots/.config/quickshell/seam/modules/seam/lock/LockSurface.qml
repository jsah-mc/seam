import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.panels.lock

MouseArea {
    id: root
    required property LockContext context
    property string wallpaperPath: ""
    property real revealProgress: 0
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: passwordField.forceActiveFocus()
    Component.onCompleted: {
        passwordField.forceActiveFocus()
        revealProgress = 1
    }

    Behavior on revealProgress {
        NumberAnimation { duration: 850; easing.type: Easing.OutCubic }
    }

    FileView {
        id: wallpaperFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/wallpaper/current.txt"
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            const value = text().trim()
            root.wallpaperPath = value.startsWith("file://") ? value : `file://${value}`
        }
        onFileChanged: reload()
    }

    Connections {
        target: context
        function onShouldReFocus() { passwordField.forceActiveFocus() }
        function onCurrentTextChanged() {
            if (passwordField.text !== context.currentText)
                passwordField.text = context.currentText
        }
    }

    Keys.onEscapePressed: {
        context.currentText = ""
        passwordField.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.m3colors.m3background

        Image {
            id: wallpaper
            anchors.fill: parent
            source: root.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: root.revealProgress
            scale: 1.08 - root.revealProgress * 0.08

            Behavior on source {
                SequentialAnimation {
                    NumberAnimation { target: wallpaper; property: "opacity"; to: 0; duration: 160 }
                    NumberAnimation { target: wallpaper; property: "opacity"; to: 1; duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.m3colors.m3scrim
            opacity: 0.48 * root.revealProgress
        }

        MaterialShape {
            id: upperShape
            anchors { left: parent.left; top: parent.top; leftMargin: -width * 0.25; topMargin: -height * 0.3 }
            implicitSize: Math.min(parent.width, parent.height) * 0.65
            shape: MaterialShape.Shape.SoftBurst
            color: Appearance.m3colors.m3primaryContainer
            opacity: 0.3 * root.revealProgress
            rotation: -12
            scale: 0.9 + root.revealProgress * 0.1
            RotationAnimation on rotation {
                from: -12
                to: 348
                duration: 32000
                loops: Animation.Infinite
                easing.type: Easing.Linear
            }
            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { to: 1.05; duration: 2800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.94; duration: 2800; easing.type: Easing.InOutSine }
            }
        }
        MaterialShape {
            id: lowerShape
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: -width * 0.3; bottomMargin: -height * 0.35 }
            implicitSize: Math.min(parent.width, parent.height) * 0.72
            shape: MaterialShape.Shape.Cookie7Sided
            color: Appearance.m3colors.m3tertiaryContainer
            opacity: 0.28 * root.revealProgress
            rotation: 18
            scale: 0.9 + root.revealProgress * 0.1
            RotationAnimation on rotation {
                from: 18
                to: -342
                duration: 38000
                loops: Animation.Infinite
                easing.type: Easing.Linear
            }
            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { to: 0.93; duration: 3400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.06; duration: 3400; easing.type: Easing.InOutSine }
            }
        }

        Column {
            id: clockColumn
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.18 }
            spacing: 2
            opacity: root.revealProgress
            transform: Translate { y: (1 - root.revealProgress) * -42 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: DateTime.time
                color: Appearance.m3colors.m3onBackground
                font.family: Appearance.font.family.numbers
                font.pixelSize: Math.min(112, root.width * 0.11)
                font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: DateTime.longDate
                color: Appearance.m3colors.m3onSurfaceVariant
                font.family: Appearance.font.family.main
                font.pixelSize: 18
            }
        }

        Column {
            id: unlockColumn
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 34 }
            spacing: 12
            opacity: root.revealProgress
            transform: Translate {
                id: unlockTranslate
                y: (1 - root.revealProgress) * 72 + failureOffset
                property real failureOffset: 0
            }

            Connections {
                target: GlobalStates
                function onScreenUnlockFailedChanged() {
                    if (GlobalStates.screenUnlockFailed)
                        failureShake.restart()
                }
            }

            SequentialAnimation {
                id: failureShake
                NumberAnimation { target: unlockTranslate; property: "failureOffset"; to: -14; duration: 55 }
                NumberAnimation { target: unlockTranslate; property: "failureOffset"; to: 14; duration: 80 }
                NumberAnimation { target: unlockTranslate; property: "failureOffset"; to: -9; duration: 70 }
                NumberAnimation { target: unlockTranslate; property: "failureOffset"; to: 9; duration: 70 }
                NumberAnimation { target: unlockTranslate; property: "failureOffset"; to: 0; duration: 90; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: GlobalStates.screenUnlockFailed ? "Incorrect password" : `Welcome, ${SystemInfo.username}`
                color: GlobalStates.screenUnlockFailed
                    ? Appearance.m3colors.m3error : Appearance.m3colors.m3onSurfaceVariant
                font.family: Appearance.font.family.main
                font.pixelSize: 14
            }

            Toolbar {
                anchors.horizontalCenter: parent.horizontalCenter
                padding: 7

                MaterialSymbol {
                    Layout.leftMargin: 8
                    Layout.alignment: Qt.AlignVCenter
                    text: context.fingerprintsConfigured ? "fingerprint" : "lock"
                    fill: 1
                    iconSize: 24
                    color: Appearance.m3colors.m3primary
                }

                ToolbarTextField {
                    id: passwordField
                    implicitWidth: Math.min(330, root.width * 0.55)
                    placeholderText: "Enter password"
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    enabled: !context.unlockInProgress
                    onTextChanged: context.currentText = text
                    onAccepted: context.tryUnlock()
                    Keys.onPressed: context.resetClearTimer()
                }

                ToolbarButton {
                    implicitWidth: height
                    toggled: true
                    enabled: !context.unlockInProgress
                    colBackgroundToggled: Appearance.m3colors.m3primary
                    onClicked: context.tryUnlock()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: context.unlockInProgress ? "progress_activity" : "arrow_right_alt"
                        iconSize: 24
                        color: Appearance.m3colors.m3onPrimary
                        RotationAnimation on rotation {
                            running: context.unlockInProgress
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            Text {
                visible: context.fingerprintsConfigured
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Touch the fingerprint sensor or enter your password"
                color: Appearance.m3colors.m3outline
                font.family: Appearance.font.family.main
                font.pixelSize: 12
            }
        }
    }
}
