pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root
    property alias agent: polkitAgent
    property alias active: polkitAgent.isActive
    property alias flow: polkitAgent.flow
    property bool interactionAvailable: false
    property string cleanMessage: {
        if (!root.flow) return "";
        const message = root.flow.message ?? "";
        return message.endsWith(".") ? message.slice(0, -1) : message
    }
    property string cleanPrompt: {
        const inputPrompt = root.flow?.inputPrompt?.trim() ?? "";
        const cleanedInputPrompt = inputPrompt.endsWith(":") ? inputPrompt.slice(0, -1) : inputPrompt;
        const usePasswordChars = !(root.flow?.responseVisible ?? false)
        return cleanedInputPrompt || (usePasswordChars ? Translation.tr("Password") : Translation.tr("Input"))
    }

    function cancel() {
        root.flow?.cancelAuthenticationRequest()
        root.interactionAvailable = false
    }

    function submit(string) {
        if (!root.flow || !root.flow.isResponseRequired || string.length === 0) return
        root.flow.submit(string)
        root.interactionAvailable = false
    }

    Connections {
        target: root.flow
        enabled: root.flow !== null
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            root.interactionAvailable = true;
        }
        function onIsCompletedChanged() {
            if (root.flow?.isCompleted) root.interactionAvailable = false
        }
        function onIsCancelledChanged() {
            if (root.flow?.isCancelled) root.interactionAvailable = false
        }
    }

    PolkitAgent {
        id: polkitAgent
        path: "/org/quickshell/SeamPolkitAgent"
        onAuthenticationRequestStarted: {
            root.interactionAvailable = true;
        }
    }
}
