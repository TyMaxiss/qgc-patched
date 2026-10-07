import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SetupPage {
    id:             serialPage
    pageComponent:  pageComponent
    showAdvanced:   false

    readonly property int  _maxSerial: 8
    readonly property real _margins:   ScreenTools.defaultFontPixelHeight * 0.5

    FactPanelController {
        id: controller
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: true
    }

    function getFact(param) {
        return controller.parameterExists(-1, param)
               ? controller.getParameterFact(-1, param, false)
               : null
    }

    function serialExists(n) {
        return controller.parameterExists(-1, "SERIAL" + n + "_PROTOCOL")
    }

    // Friendly names matching ArduPilot's serial port mapping.
    function portLabel(n) {
        switch (n) {
        case 0:  return qsTr("SERIAL0 (USB)")
        case 1:  return qsTr("SERIAL1 (Telem1)")
        case 2:  return qsTr("SERIAL2 (Telem2)")
        default: return qsTr("SERIAL%1").arg(n)
        }
    }

    // --- Live GCS link state ------------------------------------------------
    // communicationLost lives on vehicleLinkManager, not on Vehicle itself.
    property bool _linkLost:    !controller.vehicle || controller.vehicle.vehicleLinkManager.communicationLost
    property int  _rxCount:     controller.vehicle ? controller.vehicle.mavlinkReceivedCount : 0
    property real _lossPercent: controller.vehicle ? controller.vehicle.mavlinkLossPercent : 0
    property bool _receiving:   false
    property bool _pulse:       false

    on_RxCountChanged: {
        _pulse = !_pulse
        _receiving = true
        rxIdleTimer.restart()
    }

    Timer {
        id:          rxIdleTimer
        interval:    2000
        onTriggered: _receiving = false
    }

    // --- Per-port activity ---------------------------------------------------
    // The autopilot does not publish per-UART traffic counters over MAVLink, so a
    // port's state is inferred from telemetry produced by the device configured on
    // it (SERIALn_PROTOCOL). Protocols with no return telemetry report "no feedback".
    readonly property int _protoMAVLink1:    1
    readonly property int _protoMAVLink2:    2
    readonly property int _protoGPS:         5
    readonly property int _protoRangefinder: 9
    readonly property int _protoRCIN:        23
    readonly property int _protoMAVLinkHL:   43

    function protocolValue(n) {
        const fact = getFact("SERIAL" + n + "_PROTOCOL")
        return fact ? fact.rawValue : -1
    }

    function isMavlinkProtocol(proto) {
        return (proto === _protoMAVLink1) || (proto === _protoMAVLink2) || (proto === _protoMAVLinkHL)
    }

    // Nth GPS-protocol port maps to the gps / gps2 fact group in port order.
    function gpsSlotForPort(n) {
        let slot = 0
        for (let i = 0; i < n; ++i) {
            if (serialExists(i) && (protocolValue(i) === _protoGPS)) {
                slot++
            }
        }
        return slot
    }

    function portStatusText(n) {
        const vehicle = controller.vehicle
        if (!vehicle) {
            return qsTr("No vehicle")
        }

        const proto = protocolValue(n)

        if (isMavlinkProtocol(proto)) {
            if (_linkLost) {
                return qsTr("Link lost")
            }
            return _receiving ? qsTr("%1 msgs, loss %2%").arg(_rxCount).arg(_lossPercent.toFixed(1))
                              : qsTr("Idle (2 s)")
        }

        if (proto === _protoGPS) {
            const gps = (gpsSlotForPort(n) === 0) ? vehicle.gps : vehicle.gps2
            const sats = gps.count.rawValue
            if (sats <= 0) {
                return qsTr("No GPS data")
            }
            return qsTr("%1 sats, fix %2").arg(sats).arg(gps.lock.rawValue)
        }

        if (proto === _protoRCIN) {
            const rssi = vehicle.rcRSSI.rawValue
            return ((rssi > 0) && (rssi <= 100)) ? qsTr("RC RSSI %1%").arg(rssi) : qsTr("No RC data")
        }

        if (proto === _protoRangefinder) {
            const dist = vehicle.vehicle.rangeFinderDist.rawValue
            return (dist > 0) ? qsTr("%1 m").arg(dist.toFixed(2)) : qsTr("No range data")
        }

        if (proto < 0) {
            return qsTr("Disabled")
        }

        return qsTr("No feedback")
    }

    function portStatusColor(n) {
        const vehicle = controller.vehicle
        if (!vehicle) {
            return qgcPal.colorGrey
        }

        const proto = protocolValue(n)

        if (isMavlinkProtocol(proto)) {
            if (_linkLost) {
                return qgcPal.colorRed
            }
            return _receiving ? qgcPal.colorGreen : qgcPal.colorOrange
        }

        if (proto === _protoGPS) {
            const gps = (gpsSlotForPort(n) === 0) ? vehicle.gps : vehicle.gps2
            if (gps.count.rawValue <= 0) {
                return qgcPal.colorRed
            }
            return (gps.lock.rawValue >= 3) ? qgcPal.colorGreen : qgcPal.colorOrange
        }

        if (proto === _protoRCIN) {
            const rssi = vehicle.rcRSSI.rawValue
            return ((rssi > 0) && (rssi <= 100)) ? qgcPal.colorGreen : qgcPal.colorRed
        }

        if (proto === _protoRangefinder) {
            return (vehicle.vehicle.rangeFinderDist.rawValue > 0) ? qgcPal.colorGreen : qgcPal.colorRed
        }

        return qgcPal.colorGrey
    }

    Component {
        id: pageComponent

        Column {
            // Let the page grow wider than the screen so SetupPage's flickable
            // can scroll horizontally instead of clipping the ports table.
            width:   Math.max(availableWidth, implicitWidth)
            spacing: _margins

            QGCLabel {
                text:     qsTr("Configure the protocol and baud rate for each onboard serial port. Changing a serial port usually requires a vehicle reboot to take effect. The Data column is inferred from telemetry sent by the device on each port — the autopilot does not report per-port traffic, so protocols with no return telemetry show \"No feedback\".")
                wrapMode: Text.WordWrap
                width:    availableWidth
            }

            // --- Live link indication -------------------------------------
            QGCGroupBox {
                title: qsTr("Telemetry Link")

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 2

                    Rectangle {
                        width:   ScreenTools.defaultFontPixelHeight
                        height:  width
                        radius:  width / 2
                        color:   _linkLost ? qgcPal.colorRed
                                           : (_receiving ? qgcPal.colorGreen : qgcPal.colorOrange)
                        // Toggled on every received-count change so the dot blinks with traffic.
                        opacity: (_receiving && _pulse) ? 0.45 : 1.0

                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    QGCLabel {
                        text: _linkLost
                              ? qsTr("No data — telemetry link lost")
                              : (_receiving
                                 ? qsTr("Receiving: %1 msgs, loss %2%").arg(_rxCount).arg(_lossPercent.toFixed(1))
                                 : qsTr("Idle — no messages in the last 2 s"))
                    }
                }
            }

            // --- Serial port configuration table --------------------------
            QGCGroupBox {
                title: qsTr("Serial Ports")

                GridLayout {
                    columns:       5
                    rowSpacing:    ScreenTools.defaultFontPixelHeight * 0.3
                    columnSpacing: ScreenTools.defaultFontPixelWidth * 2

                    QGCLabel { text: qsTr("Port");     Layout.row: 0; Layout.column: 0 }
                    QGCLabel { text: qsTr("Protocol"); Layout.row: 0; Layout.column: 1; Layout.alignment: Qt.AlignHCenter }
                    QGCLabel { text: qsTr("Baud");     Layout.row: 0; Layout.column: 2; Layout.alignment: Qt.AlignHCenter }
                    QGCLabel { text: qsTr("Options");  Layout.row: 0; Layout.column: 3; Layout.alignment: Qt.AlignHCenter }
                    QGCLabel { text: qsTr("Data");     Layout.row: 0; Layout.column: 4; Layout.alignment: Qt.AlignHCenter }

                    // --- Column 0: Port name ---
                    Repeater {
                        model: _maxSerial

                        QGCLabel {
                            text:          portLabel(index)
                            visible:       serialExists(index)
                            Layout.row:    index + 1
                            Layout.column: 0
                        }
                    }

                    // --- Column 1: Protocol ---
                    Repeater {
                        model: _maxSerial

                        FactComboBox {
                            fact:           getFact("SERIAL" + index + "_PROTOCOL")
                            indexModel:     false
                            sizeToContents: true
                            visible:        serialExists(index)
                            Layout.row:    index + 1
                            Layout.column: 1
                        }
                    }

                    // --- Column 2: Baud rate ---
                    Repeater {
                        model: _maxSerial

                        FactComboBox {
                            fact:           getFact("SERIAL" + index + "_BAUD")
                            indexModel:     false
                            sizeToContents: true
                            visible:        serialExists(index) && (getFact("SERIAL" + index + "_BAUD") !== null)
                            Layout.row:    index + 1
                            Layout.column: 2
                        }
                    }

                    // --- Column 3: Options ---
                    Repeater {
                        model: _maxSerial

                        FactTextField {
                            fact:          getFact("SERIAL" + index + "_OPTIONS")
                            visible:       serialExists(index) && (getFact("SERIAL" + index + "_OPTIONS") !== null)
                            Layout.row:    index + 1
                            Layout.column: 3
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                        }
                    }

                    // --- Column 4: Inferred per-port activity ---
                    Repeater {
                        model: _maxSerial

                        RowLayout {
                            spacing:       ScreenTools.defaultFontPixelWidth
                            visible:       serialExists(index)
                            Layout.row:    index + 1
                            Layout.column: 4

                            property int _portNum: index

                            Rectangle {
                                width:  ScreenTools.defaultFontPixelHeight * 0.75
                                height: width
                                radius: width / 2
                                color:  portStatusColor(parent._portNum)
                            }

                            QGCLabel {
                                text:                  portStatusText(parent._portNum)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20
                            }
                        }
                    }
                }
            }
        }
    }
}
