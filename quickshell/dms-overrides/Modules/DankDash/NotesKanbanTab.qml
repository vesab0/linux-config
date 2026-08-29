import QtQuick
import qs.Common
import qs.Modules.Notepad
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    implicitWidth: SettingsData.showWeekNumber ? 736 : 700
    implicitHeight: 460

    property string activeView: "notes"

    readonly property var views: [
        {
            "id": "notes",
            "label": I18n.tr("Notes"),
            "icon": "note_stack"
        },
        {
            "id": "kanban",
            "label": I18n.tr("Kanban"),
            "icon": "view_kanban"
        }
    ]

    Column {
        id: layout
        anchors.fill: parent
        spacing: Theme.spacingM

        Row {
            id: viewSwitcher
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: root.views

                delegate: Rectangle {
                    id: tabButton

                    readonly property bool isActive: root.activeView === modelData.id

                    width: tabLabel.implicitWidth + tabIcon.width + Theme.spacingM * 2 + Theme.spacingS
                    height: 32
                    radius: Theme.cornerRadius
                    color: isActive ? Theme.primary : "transparent"
                    border.color: isActive ? "transparent" : Theme.outlineMedium
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DankIcon {
                            id: tabIcon
                            name: modelData.icon
                            size: Theme.iconSizeSmall
                            color: tabButton.isActive ? Theme.background : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            id: tabLabel
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeMedium
                            color: tabButton.isActive ? Theme.background : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeView = modelData.id
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: layout.height - viewSwitcher.height - layout.spacing

            Notepad {
                anchors.fill: parent
                visible: root.activeView === "notes"
                inPopout: true
            }

            KanbanBoard {
                anchors.fill: parent
                visible: root.activeView === "kanban"
            }
        }
    }
}
