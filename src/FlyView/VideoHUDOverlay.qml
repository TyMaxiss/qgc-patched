import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

// Mission Planner style flight HUD drawn on top of the video stream: translucent artificial
// horizon with pitch ladder and roll scale, sliding speed/altitude tapes, a heading ribbon
// and a status line. All readouts are null-guarded so the HUD is inert without a vehicle.
Item {
    id:   root
    clip: true

    property var  vehicle:        null
    /// Opacity of the sky/ground fill so the video stays visible behind the horizon.
    property real horizonOpacity: 0.35
    /// Height of the main toolbar the video pane sits under; top elements clear it.
    property real topInset:       0

    property real _roll:      root.vehicle ? root.vehicle.roll.rawValue : 0
    property real _pitch:     root.vehicle ? root.vehicle.pitch.rawValue : 0
    property real _heading:   root.vehicle ? root.vehicle.heading.rawValue : 0

    // Cooked values honour the user's unit preferences; units come from the same Fact.
    property real   _speed:      root.vehicle ? root.vehicle.groundSpeed.value : 0
    property real   _airSpeed:   root.vehicle ? root.vehicle.airSpeed.value : 0
    property real   _altitude:   root.vehicle ? root.vehicle.altitudeRelative.value : 0
    property real   _altitudeAMSL: root.vehicle ? root.vehicle.altitudeAMSL.value : 0
    property real   _climb:      root.vehicle ? root.vehicle.climbRate.value : 0
    property real   _distHome:   root.vehicle ? root.vehicle.distanceToHome.value : 0
    property real   _throttle:   root.vehicle ? root.vehicle.throttlePct.value : 0
    property string _speedUnits: root.vehicle ? root.vehicle.groundSpeed.units : ""
    property string _altUnits:   root.vehicle ? root.vehicle.altitudeRelative.units : ""
    property string _mode:       root.vehicle ? root.vehicle.flightMode : ""
    property bool   _armed:      root.vehicle ? root.vehicle.armed : false

    property real _fontSize:  ScreenTools.defaultFontPointSize * 0.9
    property real _tapeWidth: ScreenTools.defaultFontPixelWidth * 7
    property real _margin:    ScreenTools.defaultFontPixelWidth

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // ---------------------------------------------------------------- tapes
    // Sliding vertical tape: ticks scroll past a fixed centre marker showing the value.
    component VerticalTape: Item {
        id: tape

        property real   value:      0
        property real   minorStep:  1        // value between minor ticks
        property int    labelEvery: 5        // label every Nth minor tick
        property real   pixPerUnit: ScreenTools.defaultFontPixelHeight * 0.55
        property bool   labelsLeft: false    // ticks/labels drawn towards the left edge
        property string units:      ""
        /// Ticks below this are not drawn, so e.g. a speed tape shows no negative values.
        property real   minValue:   -100000

        // Enough ticks to cover the visible height either side of centre.
        property int _halfCount: Math.ceil((tape.height / 2) / Math.max(1, tape.minorStep * tape.pixPerUnit)) + 2

        clip: true

        Rectangle {
            anchors.fill: parent
            color:        Qt.rgba(0, 0, 0, 0.35)
        }

        Repeater {
            model: (tape._halfCount * 2) + 1

            Item {
                id:     tick
                width:  tape.width
                height: 1
                // Round to the nearest step so ticks stay on whole values as the tape slides.
                property real tickValue: (Math.round(tape.value / tape.minorStep) + (index - tape._halfCount)) * tape.minorStep
                property bool major:     Math.round(tickValue / tape.minorStep) % tape.labelEvery === 0
                property bool inRange:   tickValue >= tape.minValue
                y: (tape.height / 2) - ((tickValue - tape.value) * tape.pixPerUnit)

                Rectangle {
                    visible: tick.inRange
                    width:  tick.major ? ScreenTools.defaultFontPixelWidth * 1.6 : ScreenTools.defaultFontPixelWidth * 0.8
                    height: 1
                    color:  "white"
                    opacity: 0.9
                    anchors.right:  tape.labelsLeft ? parent.right : undefined
                    anchors.left:   tape.labelsLeft ? undefined : parent.left
                }

                QGCLabel {
                    visible:        tick.major && tick.inRange
                    text:           Math.round(tick.tickValue)
                    color:          "white"
                    font.pointSize: root._fontSize * 0.85
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right:  tape.labelsLeft ? parent.right : undefined
                    anchors.left:   tape.labelsLeft ? undefined : parent.left
                    anchors.rightMargin: tape.labelsLeft ? ScreenTools.defaultFontPixelWidth * 2 : 0
                    anchors.leftMargin:  tape.labelsLeft ? 0 : ScreenTools.defaultFontPixelWidth * 2
                }
            }
        }

        // Current value readout pinned to the centre of the tape.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            anchors.right:          parent.right
            height:                 ScreenTools.defaultFontPixelHeight * 1.4
            color:                  Qt.rgba(0, 0, 0, 0.8)
            border.color:           "white"
            border.width:           1

            QGCLabel {
                anchors.centerIn: parent
                text:             tape.value.toFixed(tape.minorStep < 1 ? 1 : 0)
                color:            "white"
                font.bold:        true
                font.pointSize:   root._fontSize
            }
        }

        QGCLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top:              parent.top
            anchors.topMargin:        ScreenTools.defaultFontPixelHeight * 0.2
            text:                     tape.units
            color:                    "white"
            font.pointSize:           root._fontSize * 0.8
        }
    }

    // ------------------------------------------------------- artificial horizon
    Item {
        id:           horizonArea
        anchors.fill: parent

        QGCArtificialHorizon {
            id:         horizon
            rollAngle:  root._roll
            pitchAngle: root._pitch
            opacity:    root.horizonOpacity
        }

        // Horizon line, drawn solid so it stays readable over the translucent fill.
        Item {
            anchors.fill: parent

            Rectangle {
                width:   parent.width * 1.5
                height:  2
                color:   "white"
                opacity: 0.9
                x:       (parent.width - width) / 2
                y:       (parent.height / 2) + (root._pitch * parent.height / 45) - 1

                transform: Rotation {
                    origin.x: parent.width / 2
                    origin.y: parent.height / 2 - ((parent.height / 2) + (root._pitch * parent.height / 45) - 1)
                    angle:    -root._roll
                }
            }
        }

        Item {
            anchors.centerIn: parent
            width:            parent.width * 0.4
            height:           parent.height * 0.7

            QGCPitchIndicator {
                pitchAngle: root._pitch
                rollAngle:  root._roll
                size:       parent.height
                color:      "transparent"
            }
        }
    }

    // ------------------------------------------------------------- roll scale
    Item {
        id:                       rollScale
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top
        anchors.topMargin:        ScreenTools.defaultFontPixelHeight * 2.2
        width:                    parent.width * 0.5
        height:                   parent.height * 0.28

        readonly property var _angles: [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]

        Repeater {
            model: rollScale._angles

            Rectangle {
                width:   modelData === 0 ? 3 : 2
                height:  modelData % 30 === 0 ? ScreenTools.defaultFontPixelHeight * 0.6
                                              : ScreenTools.defaultFontPixelHeight * 0.35
                color:   "white"
                opacity: 0.9
                x:       (rollScale.width / 2) - (width / 2)
                y:       0

                transform: Rotation {
                    origin.x: width / 2
                    origin.y: rollScale.height
                    angle:    modelData
                }
            }
        }

        // Pointer showing current roll against the fixed scale.
        Canvas {
            id:           rollPointer
            anchors.fill: parent

            Connections {
                target:                 root
                function on_RollChanged() { rollPointer.requestPaint() }
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = "white"
                const cx = width / 2
                const cy = height
                const r  = height * 0.92
                const a  = (-root._roll) * Math.PI / 180
                const tipX = cx + (r * Math.sin(a))
                const tipY = cy - (r * Math.cos(a))
                const s = ScreenTools.defaultFontPixelHeight * 0.35
                ctx.beginPath()
                ctx.moveTo(tipX, tipY)
                ctx.lineTo(tipX - (s * Math.cos(a)) + (s * 0.5 * Math.sin(a)), tipY - (s * Math.sin(a)) - (s * 0.5 * Math.cos(a)))
                ctx.lineTo(tipX + (s * Math.cos(a)) + (s * 0.5 * Math.sin(a)), tipY + (s * Math.sin(a)) - (s * 0.5 * Math.cos(a)))
                ctx.closePath()
                ctx.fill()
            }
        }
    }

    // ------------------------------------------------------- aircraft symbol
    Item {
        anchors.centerIn: parent
        width:            ScreenTools.defaultFontPixelWidth * 14
        height:           ScreenTools.defaultFontPixelHeight * 1.2

        Rectangle {
            anchors.left:           parent.left
            anchors.verticalCenter: parent.verticalCenter
            width:                  parent.width * 0.35
            height:                 3
            color:                  qgcPal.colorOrange
        }
        Rectangle {
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            width:                  parent.width * 0.35
            height:                 3
            color:                  qgcPal.colorOrange
        }
        Rectangle {
            anchors.centerIn: parent
            width:            5
            height:           5
            radius:           2.5
            color:            qgcPal.colorOrange
        }
    }

    // --------------------------------------------------------- heading ribbon
    Item {
        id:                       headingRibbon
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top
        // The video pane extends under the main toolbar, so clear it before drawing.
        anchors.topMargin:        root.topInset + root._margin
        width:                    Math.min(parent.width * 0.6, ScreenTools.defaultFontPixelWidth * 46)
        height:                   ScreenTools.defaultFontPixelHeight * 1.6
        clip:                     true

        property real _pixPerDeg: width / 90        // 90 degrees visible across the ribbon

        Rectangle {
            anchors.fill: parent
            color:        Qt.rgba(0, 0, 0, 0.35)
        }

        Repeater {
            model: 37       // every 5 degrees over a 180 degree span around the heading

            Item {
                id:     hTick
                width:  1
                height: headingRibbon.height
                property int tickDeg: ((Math.round(root._heading / 5) + (index - 18)) * 5 + 360) % 360
                property bool major: tickDeg % 15 === 0
                // Shortest angular distance from the current heading keeps the ribbon continuous.
                property real delta: ((tickDeg - root._heading + 540) % 360) - 180
                x: (headingRibbon.width / 2) + (delta * headingRibbon._pixPerDeg)

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top:              parent.top
                    width:                    1
                    height:                   hTick.major ? parent.height * 0.35 : parent.height * 0.2
                    color:                    "white"
                    opacity:                  0.9
                }

                QGCLabel {
                    visible:                  hTick.major
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom:           parent.bottom
                    anchors.bottomMargin:     2
                    color:                    "white"
                    font.pointSize:           root._fontSize * 0.8
                    text: {
                        switch (hTick.tickDeg) {
                        case 0:   return "N"
                        case 90:  return "E"
                        case 180: return "S"
                        case 270: return "W"
                        default:  return hTick.tickDeg
                        }
                    }
                }
            }
        }

        // Current heading box centred on the ribbon.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter:   parent.verticalCenter
            width:                    ScreenTools.defaultFontPixelWidth * 6
            height:                   parent.height * 0.9
            color:                    Qt.rgba(0, 0, 0, 0.8)
            border.color:             "white"
            border.width:             1

            QGCLabel {
                anchors.centerIn: parent
                text:             Math.round(root._heading) + "°"
                color:            "white"
                font.bold:        true
                font.pointSize:   root._fontSize
            }
        }
    }

    // ------------------------------------------------------------ speed tape
    VerticalTape {
        id:                     speedTape
        anchors.left:           parent.left
        anchors.leftMargin:     root._margin
        anchors.verticalCenter: parent.verticalCenter
        width:                  root._tapeWidth
        height:                 parent.height * 0.5
        value:                  root._speed
        minorStep:              1
        labelEvery:             5
        labelsLeft:             false
        minValue:               0
        units:                  root._speedUnits
    }

    // --------------------------------------------------------- altitude tape
    VerticalTape {
        id:                     altTape
        anchors.right:          parent.right
        anchors.rightMargin:    root._margin
        anchors.verticalCenter: parent.verticalCenter
        width:                  root._tapeWidth
        height:                 parent.height * 0.5
        value:                  root._altitude
        minorStep:              1
        labelEvery:             5
        labelsLeft:             true
        units:                  root._altUnits
    }

    // Climb rate next to the altitude tape, the way Mission Planner shows vertical speed.
    Rectangle {
        anchors.right:        altTape.left
        anchors.rightMargin:  ScreenTools.defaultFontPixelWidth * 0.5
        anchors.verticalCenter: altTape.verticalCenter
        width:                ScreenTools.defaultFontPixelWidth * 6
        height:               ScreenTools.defaultFontPixelHeight * 1.3
        color:                Qt.rgba(0, 0, 0, 0.6)

        QGCLabel {
            anchors.centerIn: parent
            text:             (root._climb >= 0 ? "+" : "") + root._climb.toFixed(1)
            color:            root._climb >= 0.2 ? qgcPal.colorGreen
                                                 : (root._climb <= -0.2 ? qgcPal.colorOrange : "white")
            font.pointSize:   root._fontSize * 0.9
            font.bold:        true
        }
    }

    // ------------------------------------------------------------ status line
    Rectangle {
        // Left aligned and lifted clear of the fly view telemetry bar, which is drawn on top
        // of the video in the bottom right corner.
        anchors.left:             parent.left
        anchors.leftMargin:       root._margin
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     ScreenTools.defaultFontPixelHeight * 3
        width:                    statusRow.width + (ScreenTools.defaultFontPixelWidth * 2)
        height:                   statusRow.height + (ScreenTools.defaultFontPixelHeight * 0.4)
        radius:                   ScreenTools.defaultFontPixelHeight / 5
        color:                    Qt.rgba(0, 0, 0, 0.6)

        Row {
            id:               statusRow
            anchors.centerIn: parent
            spacing:          ScreenTools.defaultFontPixelWidth * 2

            QGCLabel {
                text:           root._armed ? qsTr("ARMED") : qsTr("DISARMED")
                color:          root._armed ? qgcPal.colorRed : qgcPal.colorGreen
                font.bold:      true
                font.pointSize: root._fontSize
            }
            QGCLabel {
                text:           root._mode
                color:          "white"
                font.bold:      true
                font.pointSize: root._fontSize
            }
            QGCLabel {
                text:           "AS " + root._airSpeed.toFixed(1)
                color:          "white"
                font.pointSize: root._fontSize
            }
            QGCLabel {
                text:           "AMSL " + root._altitudeAMSL.toFixed(0)
                color:          "white"
                font.pointSize: root._fontSize
            }
            QGCLabel {
                text:           "HOME " + root._distHome.toFixed(0)
                color:          "white"
                font.pointSize: root._fontSize
            }
            QGCLabel {
                text:           "THR " + Math.round(root._throttle) + "%"
                color:          "white"
                font.pointSize: root._fontSize
            }
        }
    }
}
