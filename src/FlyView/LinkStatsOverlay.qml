import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Compact link statistics readout for the fly view top-right corner.
// RSSI comes from RADIO_STATUS (SiK-style datalinks, dBm) with RC RSSI (%) as
// fallback, LQ is derived from the running MAVLink loss rate, and SNR is
// RSSI minus noise floor when the radio reports both.
Rectangle {
    id: root

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    property var  _radio:      _activeVehicle ? _activeVehicle.radioStatus : null
    property int  _lrssi:      _radio ? _radio.lrssi.rawValue : 0
    property int  _rrssi:      _radio ? _radio.rrssi.rawValue : 0
    property int  _lNoise:     _radio ? _radio.lNoise.rawValue : 0
    property int  _rNoise:     _radio ? _radio.rNoise.rawValue : 0
    property bool _hasRadio:   (_lrssi !== 0) || (_rrssi !== 0)
    property bool _hasNoise:   _hasRadio && ((_lNoise !== 0) || (_rNoise !== 0))
    property int  _rcRSSI:     _activeVehicle ? _activeVehicle.rcRSSI.rawValue : 255
    property bool _hasRcRSSI:  (_rcRSSI > 0) && (_rcRSSI <= 100)
    property real _lq:         _activeVehicle ? Math.max(0, Math.min(100, 100 - _activeVehicle.mavlinkLossPercent)) : 0

    // --- RC receiver link (CRSF / ExpressLRS via RC_CHANNELS.rssi) ----------
    // ArduPilot maps the receiver reading across the full MAVLink 0-254 scale, so the raw
    // fact is used rather than the 0-100 rcRSSI fact (which rejects anything above 100).
    property int  _rcMode:   QGroundControl.settingsManager.flyViewSettings.rcLinkStatsMode.rawValue
    property int  _rcRaw:    _activeVehicle ? _activeVehicle.vehicle.rcRSSIRaw.rawValue : 255
    property bool _rcValid:  (_rcMode !== 0) && (_rcRaw <= 254)

    // Autopilots disagree on the RC_CHANNELS.rssi scale: some send 0-100, others the full
    // MAVLink 0-254 range. Assume 0-100 and latch to 254 as soon as a larger value arrives.
    property int _rcScaleMax: 100

    on_RcRawChanged: {
        if ((_rcRaw > 100) && (_rcRaw <= 254)) {
            _rcScaleMax = 254
        }
    }

    // Inverse of ArduPilot's CRSF scaling: rssi = (1 - (|dBm| - 50) / 70) * fullScale,
    // so -120 dBm maps to 0 and -50 dBm maps to full scale. Anything stronger than
    // -50 dBm is clamped by the autopilot, hence the "≥" readout at full scale.
    function _rcDbm()       { return (70.0 * (_rcRaw / _rcScaleMax)) - 120.0 }
    function _rcSaturated() { return _rcRaw >= _rcScaleMax }
    function _rcLq()        { return Math.min(100, Math.round((_rcRaw * 100.0) / _rcScaleMax)) }

    function _rcText() {
        switch (_rcMode) {
        case 1:  return _rcSaturated() ? "≥ -50 dBm" : (Math.round(_rcDbm()) + " dBm")
        case 2:  return _rcLq() + " %"
        default: return _rcRaw + " / " + _rcScaleMax
        }
    }

    function _rcColor() {
        if (_rcMode === 1) {
            const dbm = _rcDbm()
            if (dbm >= -85)  return qgcPal.colorGreen
            if (dbm >= -100) return qgcPal.colorOrange
            return qgcPal.colorRed
        }
        if (_rcMode === 2) {
            const lq = _rcLq()
            if (lq >= 80) return qgcPal.colorGreen
            if (lq >= 50) return qgcPal.colorOrange
            return qgcPal.colorRed
        }
        return "white"
    }

    visible:        _activeVehicle !== null
    color:          Qt.rgba(0, 0, 0, 0.65)
    radius:         ScreenTools.defaultFontPixelHeight / 4
    border.color:   Qt.rgba(1, 1, 1, 0.25)
    border.width:   1
    implicitWidth:  statsGrid.width + (ScreenTools.defaultFontPixelWidth * 2)
    implicitHeight: statsGrid.height + ScreenTools.defaultFontPixelHeight

    function _lqColor() {
        if (_lq >= 80) return qgcPal.colorGreen
        if (_lq >= 50) return qgcPal.colorOrange
        return qgcPal.colorRed
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    GridLayout {
        id:                 statsGrid
        anchors.centerIn:   parent
        columns:            2
        rowSpacing:         0
        columnSpacing:      ScreenTools.defaultFontPixelWidth

        QGCLabel { text: "RSSI"; color: "white"; font.pointSize: ScreenTools.smallFontPointSize }
        QGCLabel {
            color:          "white"
            font.pointSize: ScreenTools.smallFontPointSize
            font.bold:      true
            text: root._hasRadio
                  ? (root._lrssi + " / " + root._rrssi + " dBm")
                  : (root._hasRcRSSI ? (root._rcRSSI + " %") : "--")
        }

        QGCLabel { text: "LQ"; color: "white"; font.pointSize: ScreenTools.smallFontPointSize }
        QGCLabel {
            color:          root._lqColor()
            font.pointSize: ScreenTools.smallFontPointSize
            font.bold:      true
            text:           Math.round(root._lq) + " %"
        }

        QGCLabel { text: "SNR"; color: "white"; font.pointSize: ScreenTools.smallFontPointSize; visible: root._hasNoise }
        QGCLabel {
            visible:        root._hasNoise
            color:          "white"
            font.pointSize: ScreenTools.smallFontPointSize
            font.bold:      true
            text:           (root._lrssi - root._lNoise) + " / " + (root._rrssi - root._rNoise) + " dB"
        }

        // RC receiver link (ExpressLRS / CRSF). Label reflects the configured interpretation.
        QGCLabel {
            visible:        root._rcValid
            text:           (root._rcMode === 2) ? "RC LQ" : "RC"
            color:          "white"
            font.pointSize: ScreenTools.smallFontPointSize
        }
        QGCLabel {
            visible:        root._rcValid
            color:          root._rcColor()
            font.pointSize: ScreenTools.smallFontPointSize
            font.bold:      true
            text:           root._rcText()
        }
    }
}
