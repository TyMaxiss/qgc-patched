import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

SetupPage {
    id:             motorPage
    pageComponent:  pageComponent

    property bool userLetterMotorIndices: false

    readonly property int _barHeight:           10
    readonly property int _barWidth:            5
    readonly property int _sliderWidth:         15
    readonly property int _motorTimeoutSecs:    3

    function motorIndexToString(motorIndex) {
        let asciiA = 65;
        if (userLetterMotorIndices) {
            return String.fromCharCode(asciiA + motorIndex);
        } else {
            return motorIndex + 1;
        }
    }

    /// Optional firmware specific content appended below the standard motor test controls.
    /// Loaded by URL on purpose: a failure inside the add-on is then contained to the Loader
    /// instead of taking the whole motor test page down with it.
    property url extraContentSource

    FactPanelController {
        id: controller
    }

    Component {
        id: pageComponent

        Column {
            spacing: ScreenTools.defaultFontPixelHeight

            QGCLabel {
                text:       qsTr("Warning: Unable to determine motor count")
                color:      qgcPal.warningText
                visible:    controller.vehicle.motorCount == -1
            }

            Row {
                id:         motorSlider
                enabled:    safetySwitch.checked
                spacing:    ScreenTools.defaultFontPixelWidth * 4

                ValueSlider {
                    id:                 sliderThrottle
                    width:              motorButtons.width
                    label:              qsTr("Throttle")
                    from:               0
                    to:                 100
                    majorTickStepSize:  5
                    decimalPlaces: 0
                    unitsString: qsTr("%")
                }
            } // Row

            QGCLabel {
                anchors.left:   parent.left
                anchors.right:  parent.right
                wrapMode:       Text.WordWrap
                text:           qsTr("Make sure you remove all props.")
            }

            QGCLabel {
                anchors.left:   parent.left
                anchors.right:  parent.right
                wrapMode:       Text.WordWrap
                text:           qsTr("Each button drives the autopilot output with that number, which is not necessarily the motor with the same number.")
            }

            Row {
                id:         motorButtons
                enabled:    safetySwitch.checked
                spacing:    ScreenTools.defaultFontPixelWidth * 4

                Repeater {
                    id:         buttonRepeater
                    model:      controller.vehicle.motorCount === -1 ? 8 : controller.vehicle.motorCount

                    // Letter is the motor label, the caption below is the autopilot output
                    // actually driven by motorTest(). They only coincide on a default layout.
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                ScreenTools.defaultFontPixelHeight * 0.15

                        property int _outputNumber: index + 1

                        QGCButton {
                            id:         button
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:       motorIndexToString(index)
                            onClicked:  {
                                controller.vehicle.motorTest(parent._outputNumber, sliderThrottle.value, sliderThrottle.value === 0 ? 0 : _motorTimeoutSecs, true)
                            }
                        }

                        QGCLabel {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:                     qsTr("out %1").arg(parent._outputNumber)
                            font.pointSize:           ScreenTools.smallFontPointSize
                            color:                    qgcPal.text
                            opacity:                  0.7
                        }
                    }
                } // Repeater

                QGCButton {
                    id:         allButton
                    text:       qsTr("All")
                    onClicked:  {
                        for (var motorIndex=0; motorIndex<buttonRepeater.count; motorIndex++) {
                            controller.vehicle.motorTest(motorIndex + 1, sliderThrottle.value, sliderThrottle.value === 0 ? 0 : _motorTimeoutSecs, true)
                        }
                    }
                }

                QGCButton {
                    id:         allStopButton
                    text:       qsTr("Stop")
                    onClicked:  {
                        for (var motorIndex=0; motorIndex<buttonRepeater.count; motorIndex++) {
                            controller.vehicle.motorTest(motorIndex + 1, 0, 0, true)
                        }
                    }
                }
            } // Row

            Row {
                spacing: ScreenTools.defaultFontPixelWidth

                Switch {
                    id: safetySwitch
                    onClicked: {
                        if (!checked) {
                            sliderThrottle.setValue(0);
                        }
                    }
                }

                QGCLabel {
                    anchors.verticalCenter:     parent.verticalCenter
                    color:  qgcPal.warningText
                    text:   safetySwitch.checked ? qsTr("Careful : Motors are enabled") : qsTr("Propellers are removed - Enable slider and motors")
                }
            } // Row

            Loader {
                source: motorPage.extraContentSource
            }
        } // Column
    } // Component
} // SetupPage
