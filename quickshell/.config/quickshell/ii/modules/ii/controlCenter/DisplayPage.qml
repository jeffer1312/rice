import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.quickToggles
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 10

    CcCard {
        title: Translation.tr("Brightness")

        Repeater {
            model: Brightness.monitors
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    visible: Brightness.monitors.length > 1
                    text: modelData.screen?.name ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1Inactive
                }
                CcSlider {
                    Layout.fillWidth: true
                    materialSymbol: "light_mode"
                    value: modelData.brightness ?? 0
                    onMoved: modelData.setBrightness(value)
                }
            }
        }
    }

    CcCard {
        title: Translation.tr("Monitor layout")

        // Column headers: the arrows and the switch are bare controls at the end of each row,
        // and without these nothing on screen says which one is order and which is full range.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 8

            Item { Layout.fillWidth: true }

            StyledText {
                text: Translation.tr("Order")
                color: Appearance.colors.colOnLayer1Inactive
                font.pixelSize: Appearance.font.pixelSize.smaller
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 76 // two IconToolbarButtons wide
            }
            StyledText {
                text: Translation.tr("Full range")
                color: Appearance.colors.colOnLayer1Inactive
                font.pixelSize: Appearance.font.pixelSize.smaller
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 44
            }
            StyledText {
                text: Translation.tr("Above")
                color: Appearance.colors.colOnLayer1Inactive
                font.pixelSize: Appearance.font.pixelSize.smaller
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 44
            }
        }

        Repeater {
            model: DisplayLayout.ordered
            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: modelData.name
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.description
                        color: Appearance.colors.colOnLayer1Inactive
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                // Where the monitor actually landed, so the order can be checked against the
                // desk instead of guessed. Position is derived from the order, never typed in.
                StyledText {
                    text: `${modelData.x}, ${modelData.y}`
                    color: Appearance.colors.colOnLayer1Inactive
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                RowLayout {
                    Layout.preferredWidth: 76 // matches the "Order" header above
                    spacing: 0

                    IconToolbarButton {
                        // Imported positions win over the order, so the arrows would be a lie.
                        enabled: index > 0 && !DisplayLayout.usingImportedPositions
                        opacity: enabled ? 1 : 0.4
                        text: "chevron_left"
                        onClicked: DisplayLayout.move(modelData.name, -1)
                    }
                    IconToolbarButton {
                        enabled: index < DisplayLayout.ordered.length - 1 && !DisplayLayout.usingImportedPositions
                        opacity: enabled ? 1 : 0.4
                        text: "chevron_right"
                        onClicked: DisplayLayout.move(modelData.name, 1)
                    }
                }

                StyledSwitch {
                    Layout.preferredWidth: 44 // matches the "Full range" header above
                    id: rangeSwitch
                    checked: DisplayLayout.isFullRange(modelData.name)
                    // onToggled, not onCheckedChanged: only a user click writes. The initial
                    // binding evaluation during row build fired onCheckedChanged and wrote the
                    // default back over the stored value — the 300ms userReady guard lost that
                    // race whenever the window built slowly.
                    onToggled: DisplayLayout.setFullRange(modelData.name, checked)
                }

                StyledSwitch {
                    Layout.preferredWidth: 44 // matches the "Above" header
                    id: aboveSwitch
                    // The internal panel is the anchor the others stack above — it can't stack
                    // above itself, so the script ignores :above on it anyway.
                    // Imported positions replace the whole layout calculation, Above included.
                    enabled: modelData.name !== "eDP-1" && !DisplayLayout.usingImportedPositions
                    opacity: enabled ? 1 : 0.4
                    checked: DisplayLayout.isAbove(modelData.name)
                    // onToggled, not onCheckedChanged — same fix as rangeSwitch.
                    onToggled: DisplayLayout.setAbove(modelData.name, checked)
                }
            }
        }

        // Free dragging only exists in nwg-displays, and nwg writes a file this config never
        // reads, with a mode that loses the full-range modeline. Importing its coordinates is
        // what lets the drag and the full range coexist.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 8

            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                visible: DisplayLayout.usingImportedPositions
                materialIcon: "restart_alt"
                mainText: Translation.tr("Back to arrows")
                onClicked: DisplayLayout.clearImportedPositions()
            }
            RippleButtonWithIcon {
                materialIcon: "open_with"
                mainText: Translation.tr("Import positions from nwg-displays")
                onClicked: DisplayLayout.importFromNwg()
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            wrapMode: Text.Wrap
            text: DisplayLayout.usingImportedPositions ? Translation.tr("Positions came from nwg-displays, so the arrows and Above are off — the dragged coordinates decide where each monitor sits. Full range still applies here and survives replugging, which it does not if nwg is left to write the layout itself. Drag again in nwg and press Import to update; \"Back to arrows\" returns to the derived layout.") : Translation.tr("Arrows set the left-to-right order — positions are worked out from it, so two monitors can't land on top of each other. Full range forces RGB 0-255 on that output, which fixes washed out colours on HDMI/DP; it picks the right mode for each monitor's own resolution. Above stacks that monitor over the laptop panel instead of beside it. All saved per output, so home (monitor above) and work (monitors to the right) each keep their own layout automatically.")
            color: Appearance.colors.colOnLayer1Inactive
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    CcCard {
        title: Translation.tr("Workspaces per monitor")

        ConfigSwitch {
            id: bindSwitch
            // The binding below sets checked while the page is being built, which would write
            // the default straight back over the stored value. Only a human can click.
            property bool userReady: false
            Component.onCompleted: readyTimer.start()
            Timer {
                id: readyTimer
                interval: 300 // ponytail: nobody clicks this within 300ms of the panel opening
                onTriggered: bindSwitch.userReady = true
            }

            buttonIcon: "grid_view"
            text: Translation.tr("Pin workspace ranges to monitors")
            checked: Config.options.workspaceRules.bindToMonitors
            onCheckedChanged: {
                if (bindSwitch.userReady)
                    Config.options.workspaceRules.bindToMonitors = checked;
            }
        }

        ConfigSpinBox {
            id: firstBox
            visible: Config.options.workspaceRules.bindToMonitors
            icon: "looks_one"
            text: Translation.tr("First workspace")
            value: WorkspaceRules.firstWorkspace
            from: 1
            // Steps a whole machine-group at a time (1, 9, 17...): Super+<number> buckets from
            // workspace 1 in spans of ALL monitors' ranges, so any other start puts shortcut,
            // bar and ranges out of phase. >1 is the multi-PC scheme (this PC = group 2).
            stepSize: WorkspaceRules.groupSpan
            to: Math.max(1, WorkspaceRules.lastWorkspace - WorkspaceRules.groupSpan + 1)
            onValueModified: {
                Config.options.workspaceRules.firstWorkspace = firstBox.value;
            }
        }

        ConfigSpinBox {
            id: countBox
            visible: Config.options.workspaceRules.bindToMonitors
            icon: "view_column"
            text: Translation.tr("Workspaces per monitor")
            // This is bar.workspaces.shown on purpose: the bar and the Super+<number> shortcut
            // both group workspaces by it, so the range each monitor owns has to be the same
            // number or the numbers on screen won't match the monitor they land on.
            value: Config.options.bar.workspaces.shown
            from: 1
            to: 10
            stepSize: 1
            onValueModified: {
                Config.options.bar.workspaces.shown = countBox.value;
            }
        }

        Repeater {
            model: Config.options.workspaceRules.bindToMonitors ? WorkspaceRules.ranges : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: modelData.name
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.description
                        color: Appearance.colors.colOnLayer1Inactive
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }
                StyledText {
                    text: `${modelData.start} – ${modelData.end}`
                    color: Appearance.colors.colOnLayer1Inactive
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
                StyledSpinBox {
                    id: startBox
                    Layout.fillWidth: false
                    // Steps block by block, so a monitor can only ever land on a whole range
                    from: WorkspaceRules.firstWorkspace
                    to: WorkspaceRules.startOfBlock(WorkspaceRules.monitors.length - 1)
                    stepSize: WorkspaceRules.perMonitor
                    value: modelData.start
                    onValueModified: {
                        const block = Math.round((startBox.value - WorkspaceRules.firstWorkspace) / WorkspaceRules.perMonitor);
                        WorkspaceRules.setBlock(modelData.name, block);
                    }
                }
            }
        }

        RippleButtonWithIcon {
            visible: Config.options.workspaceRules.bindToMonitors
            enabled: WorkspaceRules.pendingCount > 0
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: 8
            materialIcon: "move_down"
            mainText: WorkspaceRules.pendingCount > 0 ? Translation.tr("Move %1 open workspace(s) here").arg(WorkspaceRules.pendingCount) : Translation.tr("Every workspace is in place")
            onClicked: WorkspaceRules.applyNow()
        }

        StyledText {
            visible: Config.options.workspaceRules.bindToMonitors
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            wrapMode: Text.Wrap
            text: Translation.tr("Pick which range each monitor gets — moving one onto a taken range swaps the two. The choice is saved per output, so another setup keeps its own numbers. New workspaces follow the rules on their own; the button above drags the ones already open.")
            color: Appearance.colors.colOnLayer1Inactive
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 10
        columnSpacing: 10

        CcToggleTile {
            Layout.fillWidth: true
            showStatus: true
            toggleModel: NightLightToggle {}
        }
        CcToggleTile {
            Layout.fillWidth: true
            toggleModel: DarkModeToggle {}
        }
        CcToggleTile {
            Layout.fillWidth: true
            toggleModel: GameModeToggle {}
        }
        CcToggleTile {
            Layout.fillWidth: true
            toggleModel: AntiFlashbangToggle {}
        }
    }

    Item { Layout.fillHeight: true }
}
