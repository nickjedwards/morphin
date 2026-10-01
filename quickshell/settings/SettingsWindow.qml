import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.components

Scope {
    id: root

    // Float the window, centred. Added at runtime rather than in the user's
    // Hyprland config, so it has to come back after every reload.
    function addWindowRule(): void {
        Quickshell.execDetached(["hyprctl", "eval", `hl.window_rule({ name = "${Meta.name}-settings", match = { title = "^${Meta.name} settings$" }, float = true, center = true })`]);
    }
    Component.onCompleted: addWindowRule()
    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (event.name === "configreloaded")
                root.addWindowRule();
        }
    }

    LazyLoader {
        active: SettingsState.visible

        FloatingWindow {
            id: window

            title: `${Meta.name} settings`
            implicitWidth: Theme.u(690)
            implicitHeight: Theme.u(505)
            minimumSize: Qt.size(Theme.u(560), Theme.u(360))
            color: Theme.bg

            onVisibleChanged: {
                if (!visible)
                    SettingsState.visible = false;
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        SettingsState.visible = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Back || (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier))) {
                        SettingsState.goBack();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Forward || (event.key === Qt.Key_Right && (event.modifiers & Qt.AltModifier))) {
                        SettingsState.goForward();
                        event.accepted = true;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.BackButton | Qt.ForwardButton
                    onClicked: mouse => mouse.button === Qt.BackButton ? SettingsState.goBack() : SettingsState.goForward()
                }

                // ── Sidebar ──────────────────────────────────────────
                Rectangle {
                    id: sidebar
                    width: Theme.u(115)
                    height: parent.height
                    color: Theme.sidebar

                    Rectangle {
                        id: searchBox
                        x: Theme.u(7)
                        y: Theme.u(7)
                        width: parent.width - Theme.u(14)
                        height: Theme.u(20)
                        radius: Theme.u(6)
                        color: Theme.card

                        Icon {
                            id: searchIcon
                            x: Theme.u(7)
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.search
                            size: Theme.u(8.5)
                            color: Theme.textDim
                        }
                        TextInput {
                            id: searchField
                            anchors.left: searchIcon.right
                            anchors.leftMargin: Theme.u(5)
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.u(6)
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.u(8)
                            clip: true
                            onTextChanged: SettingsState.search = text
                            onAccepted: {
                                const first = sideList.model[0];
                                if (first)
                                    SettingsState.go(first.id);
                            }

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !searchField.text
                                text: "Search Settings"
                                size: Theme.u(8)
                                color: Theme.textFaint
                            }
                        }
                    }

                    Column {
                        id: sideColumn
                        x: Theme.u(5)
                        anchors.top: searchBox.bottom
                        anchors.topMargin: Theme.u(8)
                        width: parent.width - Theme.u(10)
                        spacing: Theme.u(2)

                        Repeater {
                            id: sideList
                            model: {
                                const q = SettingsState.search.trim().toLowerCase();
                                return SettingsState.pages.filter(p => !q || p.label.toLowerCase().includes(q) || p.keywords.includes(q));
                            }

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool current: SettingsState.page === modelData.id

                                width: sideColumn.width
                                height: Theme.u(22)
                                radius: Theme.u(6)
                                color: current ? Theme.surface : sideMouse.containsMouse ? Theme.card : "transparent"

                                Rectangle {
                                    id: sideDot
                                    x: Theme.u(5)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.u(13)
                                    height: width
                                    radius: width / 2
                                    color: Theme.accentSoft

                                    Icon {
                                        anchors.centerIn: parent
                                        text: parent.parent.modelData.icon
                                        size: Theme.u(7.5)
                                        color: Theme.accent
                                    }
                                }
                                Label {
                                    anchors.left: sideDot.right
                                    anchors.leftMargin: Theme.u(7)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.modelData.label
                                    size: Theme.u(8)
                                    font.weight: parent.current ? Font.DemiBold : Font.Medium
                                }
                                MouseArea {
                                    id: sideMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SettingsState.go(parent.modelData.id)
                                }
                            }
                        }
                    }
                }

                // ── Content ──────────────────────────────────────────
                Item {
                    anchors.left: sidebar.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Row {
                        id: nav
                        x: Theme.u(12)
                        y: Theme.u(8)
                        spacing: Theme.u(4)

                        CircleButton {
                            implicitWidth: Theme.u(16)
                            icon: Icons.arrowLeft
                            iconSize: Theme.u(8)
                            idleColor: Theme.card
                            opacity: SettingsState.back.length > 0 ? 1 : 0.4
                            onClicked: SettingsState.goBack()
                        }
                        CircleButton {
                            implicitWidth: Theme.u(16)
                            icon: Icons.arrowRight
                            iconSize: Theme.u(8)
                            idleColor: Theme.card
                            opacity: SettingsState.forward.length > 0 ? 1 : 0.4
                            onClicked: SettingsState.goForward()
                        }
                    }

                    Flickable {
                        id: scroller
                        anchors.fill: parent
                        anchors.topMargin: Theme.u(30)
                        contentHeight: pagesLoader.implicitHeight + Theme.u(20)
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        SettingsPages {
                            id: pagesLoader
                            x: Theme.u(12)
                            width: scroller.width - Theme.u(24)
                        }
                    }

                    // Thin scroll indicator
                    Rectangle {
                        visible: scroller.contentHeight > scroller.height
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u(3)
                        y: scroller.y + scroller.visibleArea.yPosition * scroller.height
                        width: Theme.u(3)
                        height: scroller.visibleArea.heightRatio * scroller.height
                        radius: width / 2
                        color: Theme.surface
                    }
                }
            }
        }
    }
}
