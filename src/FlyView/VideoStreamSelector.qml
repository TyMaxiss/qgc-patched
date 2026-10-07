import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// In-flight RTSP stream switcher. Reads the semicolon/newline separated catalog from
// VideoSettings.rtspUrlList ("Name|rtsp://..." entries) and lets the operator switch the
// active stream by tapping a name. Switching just updates the rtspUrl/videoSource facts, so
// the normal VideoManager restart path applies the new source. Hidden unless 2+ streams exist.
Item {
    id: root

    // Set false by the host to hide the selector regardless of how many streams are configured
    // (e.g. when no video is decoding or the view is full-screen).
    property bool   displayActive: true

    property var    _streams:    _parseStreams(QGroundControl.settingsManager.videoSettings.rtspUrlList.rawValue)
    property string _currentUrl: QGroundControl.settingsManager.videoSettings.rtspUrl.rawValue

    visible:        displayActive && (_streams.length >= 2)
    implicitWidth:  pill.width
    implicitHeight: pill.height

    function _parseStreams(raw) {
        var out = []
        if (!raw) {
            return out
        }
        var entries = raw.split(/[;\n]/)
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i].trim()
            if (entry.length === 0) {
                continue
            }
            var name
            var url
            var bar = entry.indexOf("|")
            if (bar >= 0) {
                name = entry.substring(0, bar).trim()
                url  = entry.substring(bar + 1).trim()
            } else {
                url  = entry
                name = entry
            }
            if (url.length === 0) {
                continue
            }
            if (name.length === 0) {
                name = qsTr("Stream %1").arg(out.length + 1)
            }
            out.push({ name: name, url: url })
        }
        return out
    }

    function _selectStream(url) {
        var videoSettings = QGroundControl.settingsManager.videoSettings
        if (videoSettings.videoSource.rawValue !== videoSettings.rtspVideoSource) {
            videoSettings.videoSource.rawValue = videoSettings.rtspVideoSource
        }
        if (videoSettings.rtspUrl.rawValue !== url) {
            videoSettings.rtspUrl.rawValue = url
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Rectangle {
        id:             pill
        width:          streamRow.width + ScreenTools.defaultFontPixelWidth * 2
        height:         streamRow.height + ScreenTools.defaultFontPixelHeight * 0.4
        radius:         height / 2
        color:          Qt.rgba(0, 0, 0, 0.65)
        border.color:   Qt.rgba(1, 1, 1, 0.25)
        border.width:   1

        Row {
            id:                 streamRow
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelWidth / 2

            Repeater {
                model: root._streams

                delegate: Rectangle {
                    id:                 streamButton
                    required property var modelData
                    property bool       active: modelData.url === root._currentUrl
                    height:             streamLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.4
                    width:              streamLabel.contentWidth + ScreenTools.defaultFontPixelWidth * 2
                    radius:             height / 2
                    color:              active ? qgcPal.buttonHighlight : Qt.rgba(1, 1, 1, 0.12)

                    QGCLabel {
                        id:                 streamLabel
                        anchors.centerIn:   parent
                        text:               streamButton.modelData.name
                        color:              streamButton.active ? qgcPal.buttonHighlightText : "white"
                        font.pointSize:     ScreenTools.smallFontPointSize
                    }

                    MouseArea {
                        anchors.fill:   parent
                        onClicked:      root._selectStream(streamButton.modelData.url)
                    }
                }
            }
        }
    }
}
