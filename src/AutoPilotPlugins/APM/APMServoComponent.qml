import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SetupPage {
    id:             servoPage
    pageComponent:  pageComponent
    showAdvanced:   false

    readonly property int _maxServos: 16
    readonly property real _margins: ScreenTools.defaultFontPixelHeight * 0.5

    FactPanelController {
        id: controller
    }

    ServoOutputMonitorController {
        id: servoMonitor
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: true
    }

    // Keep the "Position (us)" bar a stable width so the table doesn't reflow.
    readonly property int _positionBarWidth: ScreenTools.defaultFontPixelWidth * 10

    function getFact(param) {
        return controller.parameterExists(-1, param)
               ? controller.getParameterFact(-1, param, false)
               : null
    }

    function servoExists(n) {
        return controller.parameterExists(-1, "SERVO" + n + "_FUNCTION")
    }

    // --- Servo test PWM helpers (Low / Mid / High, Mission Planner style) ---
    function _clampPwm(value, fallback) {
        const pwm = parseInt(value)
        if (isNaN(pwm)) {
            return fallback
        }
        return Math.max(800, Math.min(2200, pwm))
    }

    function lowPwm()  { return _clampPwm(lowPwmField.text, 1000) }
    function highPwm() { return _clampPwm(highPwmField.text, 2000) }
    function midPwm()  { return Math.round((lowPwm() + highPwm()) / 2) }

    function sendServoPwm(servoNum, pwm) {
        controller.vehicle.setServo(servoNum, pwm)
    }

    Component {
        id: pageComponent

        Column {
            // Let the page grow wider than the screen so SetupPage's flickable
            // can scroll horizontally instead of clipping the outputs table.
            width:   Math.max(availableWidth, implicitWidth)
            spacing: _margins

            QGCLabel {
                text:     qsTr("Configure ArduPilot servo outputs.")
                wrapMode: Text.WordWrap
                width:    availableWidth
            }

            QGCGroupBox {
                title: qsTr("Servo Outputs")

                GridLayout {
                    columns:       7
                    rowSpacing:    ScreenTools.defaultFontPixelHeight * 0.3
                    columnSpacing: ScreenTools.defaultFontPixelWidth * 2

                    // --- Headers (all explicitly in row 0) -----------------
                    QGCLabel { text: "";         Layout.row: 0; Layout.column: 0; Layout.alignment: Qt.AlignHCenter }
                    QGCLabel {
                        text: qsTr("Position")
                        Layout.row: 0
                        Layout.column: 1
                        Layout.alignment: Qt.AlignHCenter
                    }
                    QGCLabel { text: qsTr("Function");      Layout.row: 0; Layout.column: 2; Layout.alignment: Qt.AlignHCenter }
                    QGCLabel { text: qsTr("Min");           Layout.row: 0; Layout.column: 3; Layout.alignment: Qt.AlignHCenter }
                    QGCLabel { text: qsTr("Trim");          Layout.row: 0; Layout.column: 4; Layout.alignment: Qt.AlignHCenter }
                    QGCLabel { text: qsTr("Max");           Layout.row: 0; Layout.column: 5; Layout.alignment: Qt.AlignHCenter }
                    QGCLabel { text: qsTr("Reversed");      Layout.row: 0; Layout.column: 6; Layout.alignment: Qt.AlignHCenter }

                    // --- Column 0: Servo number ----------------------------
                    Repeater {
                        model: _maxServos

                        QGCLabel {
                            text:          index + 1
                            visible:       servoExists(index + 1)
                            Layout.row:    index + 1
                            Layout.column: 0
                        }
                    }

                    // --- Column 1: Position --------------------------------
                    Repeater {
                        id: positionRepeater
                        model: _maxServos

                        Item {
                            readonly property int _servoIndex: index + 1
                            readonly property var _minFact:  getFact("SERVO" + _servoIndex + "_MIN")
                            readonly property var _maxFact:  getFact("SERVO" + _servoIndex + "_MAX")

                            property int pwmValue: servoMonitor.servoValue(index)
                            readonly property double _rawValue: pwmValue >= 0 ? pwmValue : NaN
                            readonly property double _minValue:  _minFact ? _minFact.value : NaN
                            readonly property double _maxValue:  _maxFact ? _maxFact.value : NaN

                            readonly property double _range: _maxValue - _minValue
                            readonly property double _ratio: (_range > 0 && !isNaN(_rawValue) && !isNaN(_minValue))
                                                               ? Math.max(0, Math.min(1, (_rawValue - _minValue) / _range))
                                                               : 0

                            height: ScreenTools.defaultFontPixelHeight * 0.95
                            Layout.preferredWidth: _positionBarWidth
                            Layout.fillWidth: false
                            width: _positionBarWidth
                            visible: servoExists(_servoIndex)
                            Layout.row: index + 1
                            Layout.column: 1

                            readonly property color _trackColor: qgcPal.colorGrey
                            // Use a themed accent so the fill is always clearly distinct from the track
                            readonly property color _progressColor: qgcPal.colorGreen

                            readonly property bool _hasValidValue: pwmValue >= 0 && !isNaN(_rawValue) && !isNaN(_minValue) && !isNaN(_maxValue) && _range > 0
                            // Use the delegate width (cell width), not `parent.width` (Repeater/GridLayout width).
                            readonly property real _progressWidth: _hasValidValue ? Math.max(0, _ratio * width) : 0

                            // Keep the delegate's implicit width stable so GridLayout doesn't reflow
                            // based on changing label text lengths.
                            implicitWidth: 0

                            Rectangle {
                                anchors.fill: parent
                                id:      track
                                color:   _trackColor
                                opacity: 0.45
                                border.width: 1
                                border.color: qgcPal.text
                                radius: ScreenTools.defaultBorderRadius
                            }

                            Rectangle {
                                anchors.top:    parent.top
                                anchors.bottom: parent.bottom
                                anchors.left:   parent.left
                                width:          _progressWidth
                                color:          _progressColor
                                radius: ScreenTools.defaultBorderRadius
                            }

                            QGCLabel {
                                id: valueLabel
                                z:  1
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment:   Text.AlignVCenter
                                text: _hasValidValue ? Math.round(_rawValue) : "-"
                                font.bold: true
                                color: qgcPal.text
                                width: parent.width
                            }
                        }
                    }

                    Connections {
                        target: servoMonitor
                        function onServoValueChanged(servo, pwmValue) {
                            const item = positionRepeater.itemAt(servo)
                            if (item) {
                                item.pwmValue = pwmValue
                            }
                        }
                    }

                    // --- Column 2: Function --------------------------------
                    Repeater {
                        model: _maxServos

                        FactComboBox {
                            fact:           getFact("SERVO" + (index + 1) + "_FUNCTION")
                            indexModel:     false
                            sizeToContents: true
                            visible:        servoExists(index + 1)
                            Layout.row:    index + 1
                            Layout.column: 2
                        }
                    }

                    // --- Column 3: Min ---------------------------------------
                    Repeater {
                        model: _maxServos

                        RowLayout {
                            spacing:       ScreenTools.defaultFontPixelWidth / 2
                            visible:       servoExists(index + 1)
                            Layout.row:    index + 1
                            Layout.column: 3

                            readonly property var spFact: getFact("SERVO" + (index + 1) + "_MIN")
                            property int _repeatDir: 0

                            Timer {
                                id: repeatInitial
                                interval: 350
                                repeat: false
                                running: false
                                onTriggered: repeatTimer.start()
                            }

                            Timer {
                                id: repeatTimer
                                interval: 80
                                repeat: true
                                running: false
                                onTriggered: if (spFact && _repeatDir !== 0) { spFact.value += _repeatDir }
                            }

                            QGCButton {
                                text: "-"
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                Layout.preferredWidth:  ScreenTools.implicitTextFieldHeight
                                Layout.preferredHeight: ScreenTools.implicitTextFieldHeight
                                onPressed: {
                                    if (!spFact) {
                                        _repeatDir = 0
                                        return
                                    }
                                    _repeatDir = -1
                                    spFact.value -= 1
                                    repeatInitial.start()
                                }
                                onReleased: {
                                    _repeatDir = 0
                                    repeatInitial.stop()
                                    repeatTimer.stop()
                                }
                            }
                            FactTextField { fact: spFact; showUnits: false; Layout.fillWidth: true }
                            QGCButton {
                                text: "+"
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                Layout.preferredWidth:  ScreenTools.implicitTextFieldHeight
                                Layout.preferredHeight: ScreenTools.implicitTextFieldHeight
                                onPressed: {
                                    if (!spFact) {
                                        _repeatDir = 0
                                        return
                                    }
                                    _repeatDir = 1
                                    spFact.value += 1
                                    repeatInitial.start()
                                }
                                onReleased: {
                                    _repeatDir = 0
                                    repeatInitial.stop()
                                    repeatTimer.stop()
                                }
                            }
                        }
                    }

                    // --- Column 4: Trim --------------------------------------
                    Repeater {
                        model: _maxServos

                        RowLayout {
                            spacing:       ScreenTools.defaultFontPixelWidth / 2
                            visible:       servoExists(index + 1)
                            Layout.row:    index + 1
                            Layout.column: 4

                            readonly property var spFact: getFact("SERVO" + (index + 1) + "_TRIM")
                            property int _repeatDir: 0

                            Timer {
                                id: repeatInitialTrim
                                interval: 350
                                repeat: false
                                running: false
                                onTriggered: repeatTimerTrim.start()
                            }

                            Timer {
                                id: repeatTimerTrim
                                interval: 80
                                repeat: true
                                running: false
                                onTriggered: if (spFact && _repeatDir !== 0) { spFact.value += _repeatDir }
                            }

                            QGCButton {
                                text: "-"
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                Layout.preferredWidth:  ScreenTools.implicitTextFieldHeight
                                Layout.preferredHeight: ScreenTools.implicitTextFieldHeight
                                onPressed: {
                                    if (!spFact) {
                                        _repeatDir = 0
                                        return
                                    }
                                    _repeatDir = -1
                                    spFact.value -= 1
                                    repeatInitialTrim.start()
                                }
                                onReleased: {
                                    _repeatDir = 0
                                    repeatInitialTrim.stop()
                                    repeatTimerTrim.stop()
                                }
                            }
                            FactTextField { fact: spFact; showUnits: false; Layout.fillWidth: true }
                            QGCButton {
                                text: "+"
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                Layout.preferredWidth:  ScreenTools.implicitTextFieldHeight
                                Layout.preferredHeight: ScreenTools.implicitTextFieldHeight
                                onPressed: {
                                    if (!spFact) {
                                        _repeatDir = 0
                                        return
                                    }
                                    _repeatDir = 1
                                    spFact.value += 1
                                    repeatInitialTrim.start()
                                }
                                onReleased: {
                                    _repeatDir = 0
                                    repeatInitialTrim.stop()
                                    repeatTimerTrim.stop()
                                }
                            }
                        }
                    }

                    // --- Column 5: Max ---------------------------------------
                    Repeater {
                        model: _maxServos

                        RowLayout {
                            spacing:       ScreenTools.defaultFontPixelWidth / 2
                            visible:       servoExists(index + 1)
                            Layout.row:    index + 1
                            Layout.column: 5

                            readonly property var spFact: getFact("SERVO" + (index + 1) + "_MAX")
                            property int _repeatDir: 0

                            Timer {
                                id: repeatInitialMax
                                interval: 350
                                repeat: false
                                running: false
                                onTriggered: repeatTimerMax.start()
                            }

                            Timer {
                                id: repeatTimerMax
                                interval: 80
                                repeat: true
                                running: false
                                onTriggered: if (spFact && _repeatDir !== 0) { spFact.value += _repeatDir }
                            }

                            QGCButton {
                                text: "-"
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                Layout.preferredWidth:  ScreenTools.implicitTextFieldHeight
                                Layout.preferredHeight: ScreenTools.implicitTextFieldHeight
                                onPressed: {
                                    if (!spFact) {
                                        _repeatDir = 0
                                        return
                                    }
                                    _repeatDir = -1
                                    spFact.value -= 1
                                    repeatInitialMax.start()
                                }
                                onReleased: {
                                    _repeatDir = 0
                                    repeatInitialMax.stop()
                                    repeatTimerMax.stop()
                                }
                            }
                            FactTextField { fact: spFact; showUnits: false; Layout.fillWidth: true }
                            QGCButton {
                                text: "+"
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                Layout.preferredWidth:  ScreenTools.implicitTextFieldHeight
                                Layout.preferredHeight: ScreenTools.implicitTextFieldHeight
                                onPressed: {
                                    if (!spFact) {
                                        _repeatDir = 0
                                        return
                                    }
                                    _repeatDir = 1
                                    spFact.value += 1
                                    repeatInitialMax.start()
                                }
                                onReleased: {
                                    _repeatDir = 0
                                    repeatInitialMax.stop()
                                    repeatTimerMax.stop()
                                }
                            }
                        }
                    }

                    // --- Column 6: Reversed ---------------------------------
                    Repeater {
                        model: _maxServos

                        FactCheckBox {
                            fact:          getFact("SERVO" + (index + 1) + "_REVERSED")
                            visible:       servoExists(index + 1)
                            Layout.row:    index + 1
                            Layout.column: 6
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            QGCGroupBox {
                title: qsTr("Servo Output Test")

                Column {
                    spacing: _margins

                    QGCLabel {
                        text:     qsTr("Drive a servo output to the Low / Mid / High PWM values below (MAV_CMD_DO_SET_SERVO). Remove propellers and secure the vehicle before testing.")
                        wrapMode: Text.WordWrap
                        color:    qgcPal.warningText
                        width:    availableWidth * 0.9
                    }

                    QGCCheckBox {
                        id:   testEnableCheckBox
                        text: qsTr("Enable servo output testing")
                    }

                    // Shared Low/High PWM used by every servo row; Mid is their average.
                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel { text: qsTr("Low PWM") }
                        QGCTextField {
                            id:                    lowPwmField
                            text:                  "1000"
                            validator:             IntValidator { bottom: 800; top: 2200 }
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                        }

                        QGCLabel { text: qsTr("High PWM"); Layout.leftMargin: ScreenTools.defaultFontPixelWidth }
                        QGCTextField {
                            id:                    highPwmField
                            text:                  "2000"
                            validator:             IntValidator { bottom: 800; top: 2200 }
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                        }

                        QGCLabel {
                            Layout.leftMargin: ScreenTools.defaultFontPixelWidth
                            text:              qsTr("Mid: %1 us").arg(midPwm())
                        }
                    }

                    Repeater {
                        model: _maxServos

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            visible: servoExists(index + 1)

                            property int _servoNum: index + 1

                            QGCLabel {
                                text:                  qsTr("Servo %1").arg(parent._servoNum)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                            }

                            QGCButton {
                                text:      qsTr("Low")
                                enabled:   testEnableCheckBox.checked
                                onClicked: sendServoPwm(parent._servoNum, lowPwm())
                            }

                            QGCButton {
                                text:      qsTr("Mid")
                                enabled:   testEnableCheckBox.checked
                                onClicked: sendServoPwm(parent._servoNum, midPwm())
                            }

                            QGCButton {
                                text:      qsTr("High")
                                enabled:   testEnableCheckBox.checked
                                onClicked: sendServoPwm(parent._servoNum, highPwm())
                            }

                            QGCLabel {
                                text:                  qsTr("Position: %1 us").arg(servoMonitor.servoValue(parent._servoNum - 1))
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16
                            }
                        }
                    }
                }
            }
        }
    }
}
