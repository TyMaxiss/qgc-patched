import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Compass priority management for ArduPilot, equivalent to the Mission Planner compass screen.
//
// ArduPilot keeps two separate lists: COMPASS_DEV_IDn is what the firmware DETECTED this boot,
// COMPASS_PRIOn_ID is what is CONFIGURED and stored. A compass that has been unplugged still
// occupies a priority slot, which is why the stock QGC page cannot get rid of it.
//
// Removal is done the way Mission Planner does it: rewrite COMPASS_PRIO1/2/3_ID from the
// surviving devices and zero the tail. COMPASS_DEV_IDn is never written - ArduPilot marks it
// read only and the wiki explicitly warns against setting it by hand.
Item {
    id: root

    implicitHeight: layout.implicitHeight

    readonly property bool available: compassController.parameterExists(-1, "COMPASS_PRIO1_ID")

    FactPanelController { id: compassController }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function _fact(name) {
        return compassController.parameterExists(-1, name)
               ? compassController.getParameterFact(-1, name, false)
               : null
    }

    function _devIdFact(i) { return root._fact("COMPASS_DEV_ID" + (i === 0 ? "" : (i + 1))) }
    function _prioFact(i)  { return root._fact("COMPASS_PRIO" + (i + 1) + "_ID") }

    /// Device ids the firmware actually found on this boot.
    function detectedIds() {
        var ids = []
        for (var i = 0; i < 3; i++) {
            var f = root._devIdFact(i)
            if (f && (f.rawValue > 0)) {
                ids.push(f.rawValue)
            }
        }
        return ids
    }

    /// Device ids currently occupying the three priority slots, in order.
    function priorityIds() {
        var ids = []
        for (var i = 0; i < 3; i++) {
            var f = root._prioFact(i)
            ids.push(f ? f.rawValue : 0)
        }
        return ids
    }

    function isMissing(id) {
        return (id > 0) && (root.detectedIds().indexOf(id) === -1)
    }

    function missingCount() {
        var n = 0
        var prio = root.priorityIds()
        for (var i = 0; i < prio.length; i++) {
            if (root.isMissing(prio[i])) {
                n++
            }
        }
        return n
    }

    /// Write an ordered list of device ids into the priority slots, zero padding the tail.
    function _writePriorities(list) {
        for (var i = 0; i < 3; i++) {
            var f = root._prioFact(i)
            if (f) {
                var value = (i < list.length) ? list[i] : 0
                if (f.rawValue !== value) {
                    f.rawValue = value
                }
            }
        }
        root._promptReboot()
    }

    /// Keep only detected devices, then give any newly detected compass a slot.
    function removeMissing() {
        var detected = root.detectedIds()
        var prio = root.priorityIds()
        var kept = []
        for (var i = 0; i < prio.length; i++) {
            if ((prio[i] > 0) && (detected.indexOf(prio[i]) !== -1)) {
                kept.push(prio[i])
            }
        }
        for (var j = 0; j < detected.length; j++) {
            if (kept.indexOf(detected[j]) === -1) {
                kept.push(detected[j])
            }
        }
        root._writePriorities(kept.slice(0, 3))
    }

    function removeAt(slot) {
        var prio = root.priorityIds()
        var kept = []
        for (var i = 0; i < prio.length; i++) {
            if ((i !== slot) && (prio[i] > 0)) {
                kept.push(prio[i])
            }
        }
        root._writePriorities(kept)
    }

    function moveUp(slot) {
        if (slot <= 0) {
            return
        }
        var prio = root.priorityIds()
        var tmp = prio[slot - 1]
        prio[slot - 1] = prio[slot]
        prio[slot] = tmp
        root._writePriorities(prio)
    }

    function _promptReboot() {
        QGroundControl.showMessageDialog(
            root,
            qsTr("Compass order changed"),
            qsTr("Compass priorities have been written. ArduPilot needs a reboot before the new order takes effect and will refuse to arm until then.\n\nReboot the vehicle now?"),
            Dialog.Cancel | Dialog.Ok,
            function() { compassController.vehicle.rebootVehicle() })
    }

    ColumnLayout {
        id:      layout
        width:   root.width
        spacing: ScreenTools.defaultFontPixelHeight / 2

        QGCLabel {
            text:      qsTr("Compass priority")
            font.bold: true
        }

        QGCLabel {
            Layout.fillWidth: true
            wrapMode:         Text.WordWrap
            text:             qsTr("Priority 1 is the preferred compass. MISSING means the compass is no longer detected, for example after unplugging it.")
        }

        Repeater {
            model: 3

            RowLayout {
                id:               slotRow
                Layout.fillWidth: true
                spacing:          ScreenTools.defaultFontPixelWidth

                property int  _slot:    index
                property int  _id:      root.priorityIds()[index]
                property bool _used:    slotRow._id > 0
                property bool _missing: root.isMissing(slotRow._id)

                QGCLabel {
                    text:      qsTr("P%1").arg(slotRow._slot + 1)
                    font.bold: true
                }

                APMSensorIdDecoder {
                    Layout.fillWidth: true
                    elide:            Text.ElideRight
                    visible:          slotRow._used
                    fact:             root._prioFact(slotRow._slot)
                }

                QGCLabel {
                    Layout.fillWidth: true
                    visible:          !slotRow._used
                    text:             qsTr("empty")
                    opacity:          0.6
                }

                QGCLabel {
                    visible:   slotRow._used && slotRow._missing
                    text:      qsTr("MISSING")
                    color:     qgcPal.warningText
                    font.bold: true
                }

                QGCButton {
                    text:      qsTr("Up")
                    enabled:   slotRow._used && (slotRow._slot > 0)
                    onClicked: root.moveUp(slotRow._slot)
                }

                QGCButton {
                    text:      qsTr("Remove")
                    enabled:   slotRow._used
                    onClicked: root.removeAt(slotRow._slot)
                }
            }
        }

        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth

            QGCButton {
                text:      qsTr("Remove missing")
                enabled:   root.missingCount() > 0
                primary:   root.missingCount() > 0
                onClicked: root.removeMissing()
            }

            QGCLabel {
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                visible:          root.missingCount() === 0
                text:             qsTr("All compasses present.")
                opacity:          0.7
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            wrapMode:         Text.WordWrap
            color:            qgcPal.warningText
            text:             qsTr("If a removed compass comes back after a reboot, run a full compass calibration with it unplugged.")
        }
    }
}
