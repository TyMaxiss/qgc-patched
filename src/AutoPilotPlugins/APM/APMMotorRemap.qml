import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Betaflight style motor order wizard for ArduPilot.
//
// ArduPilot has no motor order table: the order is defined by which output carries which
// motor function, i.e. SERVOn_FUNCTION. The wizard spins one board output at a time
// (MAV_CMD_DO_MOTOR_TEST is sent in board order), asks the operator which arm actually
// turned, and finally writes SERVOn_FUNCTION for every output at once.
//
// Motor geometry below is the layout ArduPilot itself uses in AP_MotorsMatrix. Angles are
// degrees from the nose, positive clockwise seen from above; cw is the propeller direction.
Item {
    id: root

    implicitWidth:  remapButton.width
    implicitHeight: remapButton.height

    // Self contained: the controller resolves the active vehicle on its own, so this component
    // does not depend on anything being injected from the page that loads it.
    FactPanelController { id: paramController }

    property var _vehicle: paramController.vehicle

    property int _frameClass: _param("FRAME_CLASS")
    property int _frameType:  _param("FRAME_TYPE")

    // Layout for the current frame, or an empty list when the frame is not described here.
    property var _layout: _layoutFor(_frameClass, _frameType)

    // Output number (1 based) -> index into _layout chosen by the operator.
    property var _assignment: ({})
    property int _currentOutput: 0          // output being spun right now, 0 = idle
    property int _spinPercent: 12

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function _param(name) {
        if (!paramController || !paramController.parameterExists(-1, name)) {
            return -1
        }
        return paramController.getParameterFact(-1, name, false).rawValue
    }

    // SERVOn_FUNCTION value for a motor number. The enum is not contiguous: motors 1-8 are
    // 33-40 while motors 9-12 jump to 82-85, so a lookup is used rather than arithmetic.
    function _motorFunction(motorNumber) {
        if ((motorNumber >= 1) && (motorNumber <= 8)) {
            return 32 + motorNumber
        }
        if ((motorNumber >= 9) && (motorNumber <= 12)) {
            return 73 + motorNumber      // 9 -> 82 ... 12 -> 85
        }
        return -1
    }

    // Motor tables taken from ArduPilot AP_MotorsMatrix. Each entry: motor number as
    // ArduPilot counts it, arm angle in degrees from the nose, and propeller direction.
    function _layoutFor(frameClass, frameType) {
        // FRAME_CLASS 1 = Quad
        if (frameClass === 1) {
            switch (frameType) {
            case 0:  // Plus
                return [{ m: 1, a:   90, cw: false }, { m: 2, a:  -90, cw: false },
                        { m: 3, a:    0, cw: true  }, { m: 4, a:  180, cw: true  }]
            case 1:  // X
                return [{ m: 1, a:   45, cw: false }, { m: 2, a: -135, cw: false },
                        { m: 3, a:  -45, cw: true  }, { m: 4, a:  135, cw: true  }]
            case 3:  // H - same positions as X, opposite directions
                return [{ m: 1, a:   45, cw: true  }, { m: 2, a: -135, cw: true  },
                        { m: 3, a:  -45, cw: false }, { m: 4, a:  135, cw: false }]
            case 6:  // Plus reversed
                return [{ m: 1, a:   90, cw: true  }, { m: 2, a:  -90, cw: true  },
                        { m: 3, a:    0, cw: false }, { m: 4, a:  180, cw: false }]
            case 12: // Betaflight X
                return [{ m: 1, a:  135, cw: true  }, { m: 2, a:   45, cw: false },
                        { m: 3, a: -135, cw: false }, { m: 4, a:  -45, cw: true  }]
            case 13: // DJI X
                return [{ m: 1, a:   45, cw: false }, { m: 2, a:  -45, cw: true  },
                        { m: 3, a: -135, cw: false }, { m: 4, a:  135, cw: true  }]
            }
        }
        // FRAME_CLASS 2 = Hexa
        if (frameClass === 2) {
            switch (frameType) {
            case 1:  // X
                return [{ m: 1, a:   90, cw: true  }, { m: 2, a:  -90, cw: false },
                        { m: 3, a:  -30, cw: true  }, { m: 4, a:  150, cw: false },
                        { m: 5, a:   30, cw: false }, { m: 6, a: -150, cw: true  }]
            case 3:  // H - X positions widened, same roles
                return [{ m: 1, a:   90, cw: true  }, { m: 2, a:  -90, cw: false },
                        { m: 3, a:  -45, cw: true  }, { m: 4, a:  135, cw: false },
                        { m: 5, a:   45, cw: false }, { m: 6, a: -135, cw: true  }]
            case 13: // DJI X
                return [{ m: 1, a:   30, cw: false }, { m: 2, a:  -30, cw: true  },
                        { m: 3, a:  -90, cw: false }, { m: 4, a: -150, cw: true  },
                        { m: 5, a:  150, cw: false }, { m: 6, a:   90, cw: true  }]
            }
        }
        return []
    }

    function _motorCount() {
        return root._layout.length
    }

    function _resetWizard() {
        root._assignment = ({})
        root._currentOutput = 0
    }

    function _assignedCount() {
        return Object.keys(root._assignment).length
    }

    /// Index in _layout already claimed by another output, or -1.
    function _outputForLayoutIndex(layoutIndex) {
        for (var key in root._assignment) {
            if (root._assignment[key] === layoutIndex) {
                return parseInt(key)
            }
        }
        return -1
    }

    function _spinOutput(output) {
        root._currentOutput = output
        // motorTest sends MOTOR_TEST_ORDER_BOARD, so the first argument is the board output.
        root._vehicle.motorTest(output, root._spinPercent, 4, true)
    }

    function _stopAll() {
        for (var i = 1; i <= root._motorCount(); i++) {
            root._vehicle.motorTest(i, 0, 0, false)
        }
        root._currentOutput = 0
    }

    function _applyMapping() {
        for (var key in root._assignment) {
            var output = parseInt(key)
            var motorNumber = root._layout[root._assignment[key]].m
            var funcValue = root._motorFunction(motorNumber)
            var paramName = "SERVO" + output + "_FUNCTION"
            if ((funcValue > 0) && paramController.parameterExists(-1, paramName)) {
                paramController.getParameterFact(-1, paramName, false).rawValue = funcValue
            }
        }
    }

    function _mappingSummary() {
        var lines = []
        for (var i = 1; i <= root._motorCount(); i++) {
            if (i in root._assignment) {
                lines.push(qsTr("Output %1  ->  Motor %2").arg(i).arg(root._layout[root._assignment[i]].m))
            }
        }
        return lines.join("\n")
    }

    QGCButton {
        id:        remapButton
        text:      qsTr("Remap motors")
        enabled:   root._vehicle && !root._vehicle.armed
        onClicked: {
            root._resetWizard()
            remapDialogFactory.open()
        }
    }

    QGCPopupDialogFactory {
        id:              remapDialogFactory
        dialogComponent: remapDialogComponent
    }

    QGCLabel {
        anchors.left:       remapButton.right
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter: remapButton.verticalCenter
        visible:            root._vehicle && root._vehicle.armed
        color:              qgcPal.warningText
        text:               qsTr("Disarm to remap motors")
    }

    Component {
        id: remapDialogComponent

        QGCPopupDialog {
            title:   qsTr("Motor order wizard")
            buttons: Dialog.Close

            onRejected: root._stopAll()

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCLabel {
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                color:            qgcPal.warningText
                text:             qsTr("REMOVE ALL PROPELLERS. Each step spins one motor at low throttle. Click the arm that actually turned. Nothing is written to the vehicle until you confirm at the end.")
            }

            QGCLabel {
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                visible:          root._motorCount() === 0
                color:            qgcPal.colorRed
                text:             qsTr("This frame (FRAME_CLASS %1, FRAME_TYPE %2) is not described by the wizard. Set the motor functions manually in the Servo Outputs page.").arg(root._frameClass).arg(root._frameType)
            }

            RowLayout {
                Layout.fillWidth: true
                visible:          root._motorCount() > 0
                spacing:          ScreenTools.defaultFontPixelWidth

                QGCLabel { text: qsTr("Test throttle") }
                QGCLabel {
                    text:      root._spinPercent + " %"
                    font.bold: true
                }
                Slider {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20
                    from:                  5
                    to:                    30
                    stepSize:              1
                    value:                 root._spinPercent
                    onMoved:               root._spinPercent = Math.round(value)
                }
            }

            // ------------------------------------------------------------ diagram
            Item {
                id:                     diagramArea
                Layout.alignment:       Qt.AlignHCenter
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 46
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 20
                visible:                root._motorCount() > 0

                property real _cx:     width / 2
                property real _cy:     height / 2
                property real _radius: Math.min(width, height) * 0.36
                property real _dotSize: ScreenTools.defaultFontPixelHeight * 2.4

                // Nose marker so the operator knows which way the diagram is oriented.
                QGCLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top:              parent.top
                    text:                     qsTr("NOSE")
                    font.bold:                true
                    color:                    qgcPal.colorGreen
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y:                        diagramArea._cy - diagramArea._radius - (diagramArea._dotSize / 2)
                    width:                    2
                    height:                   diagramArea._radius * 0.5
                    color:                    qgcPal.colorGreen
                }

                // Frame arms
                Repeater {
                    model: root._layout

                    Rectangle {
                        width:  2
                        height: diagramArea._radius
                        color:  qgcPal.text
                        opacity: 0.5
                        x:      diagramArea._cx - 1
                        y:      diagramArea._cy - diagramArea._radius
                        transform: Rotation {
                            origin.x: 1
                            origin.y: diagramArea._radius
                            angle:    modelData.a
                        }
                    }
                }

                // Motor positions
                Repeater {
                    model: root._layout

                    Rectangle {
                        id:      motorDot
                        width:   diagramArea._dotSize
                        height:  width
                        radius:  width / 2
                        x:       diagramArea._cx + (diagramArea._radius * Math.sin(modelData.a * Math.PI / 180)) - (width / 2)
                        y:       diagramArea._cy - (diagramArea._radius * Math.cos(modelData.a * Math.PI / 180)) - (height / 2)

                        property int  _layoutIndex: index
                        property int  _claimedBy:   root._outputForLayoutIndex(index)
                        property bool _claimed:     _claimedBy !== -1
                        property bool _selectable:  root._currentOutput > 0 && !_claimed

                        color: _claimed ? qgcPal.colorGreen
                                        : (_selectable ? qgcPal.buttonHighlight : qgcPal.windowShade)
                        border.color: qgcPal.text
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing:          0

                            QGCLabel {
                                Layout.alignment: Qt.AlignHCenter
                                text:             modelData.m
                                font.bold:        true
                                color:            motorDot._claimed ? qgcPal.buttonHighlightText : qgcPal.text
                            }
                            QGCLabel {
                                Layout.alignment: Qt.AlignHCenter
                                text:             modelData.cw ? qsTr("CW") : qsTr("CCW")
                                font.pointSize:   ScreenTools.smallFontPointSize
                                color:            motorDot._claimed ? qgcPal.buttonHighlightText : qgcPal.text
                            }
                        }

                        // Output number claimed for this position
                        QGCLabel {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top:              parent.bottom
                            visible:                  motorDot._claimed
                            text:                     qsTr("out %1").arg(motorDot._claimedBy)
                            font.pointSize:           ScreenTools.smallFontPointSize
                            color:                    qgcPal.colorGreen
                        }

                        QGCMouseArea {
                            fillItem: parent
                            enabled:  motorDot._selectable
                            onClicked: {
                                // A fresh object is required: reassigning the same reference
                                // would not notify the bindings that read _assignment.
                                var updated = Object.assign({}, root._assignment)
                                updated[root._currentOutput] = motorDot._layoutIndex
                                root._vehicle.motorTest(root._currentOutput, 0, 0, false)
                                root._currentOutput = 0
                                root._assignment = updated
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------------ controls
            QGCLabel {
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                visible:          root._motorCount() > 0
                text: root._currentOutput > 0
                      ? qsTr("Output %1 is spinning. Click the arm that turned.").arg(root._currentOutput)
                      : (root._assignedCount() === root._motorCount()
                         ? qsTr("All %1 motors identified. Review the mapping and apply.").arg(root._motorCount())
                         : qsTr("Assigned %1 of %2. Press Spin next output.").arg(root._assignedCount()).arg(root._motorCount()))
            }

            RowLayout {
                Layout.fillWidth: true
                visible:          root._motorCount() > 0
                spacing:          ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text:    qsTr("Spin next output")
                    enabled: root._currentOutput === 0 && root._assignedCount() < root._motorCount()
                    onClicked: {
                        for (var i = 1; i <= root._motorCount(); i++) {
                            if (!(i in root._assignment)) {
                                root._spinOutput(i)
                                break
                            }
                        }
                    }
                }

                QGCButton {
                    text:      qsTr("Stop")
                    enabled:   root._currentOutput > 0
                    onClicked: root._stopAll()
                }

                QGCButton {
                    text:      qsTr("Start over")
                    onClicked: { root._stopAll(); root._resetWizard() }
                }

                Item { Layout.fillWidth: true }

                QGCButton {
                    text:      qsTr("Apply")
                    primary:   true
                    enabled:   root._assignedCount() === root._motorCount() && root._motorCount() > 0
                    onClicked: {
                        root._stopAll()
                        QGroundControl.showMessageDialog(
                            root,
                            qsTr("Apply motor order"),
                            qsTr("The following outputs will be reassigned:\n\n%1\n\nThe vehicle must be rebooted for this to take effect. Re-run the motor test afterwards and verify every motor before flying.").arg(root._mappingSummary()),
                            Dialog.Cancel | Dialog.Ok,
                            function() { root._applyMapping() })
                    }
                }
            }
            }
        }
    }
}
