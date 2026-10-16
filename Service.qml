import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import "Countdown.js" as Countdown

// Alerte plein écran (non interactive) au débranchement / rebranchement du
// câble ombilical, comme l'annonce « 内部電源に切り替わりました » de la NERV.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property color amber: "#FF8A1F"
  readonly property color lime: "#86E33F"

  readonly property var device: UPower.displayDevice
  readonly property bool present: !!(device && device.isPresent)
  property bool internal: false
  property bool alertVisible: false
  property bool ready: false

  Component.onCompleted: { internal = UPower.onBattery; ready = true }

  Connections {
    target: UPower
    function onOnBatteryChanged() {
      root.internal = UPower.onBattery
      if (root.ready && root.present) { root.alertVisible = true; hideTimer.restart() }
    }
  }

  Timer { id: hideTimer; interval: 3800; onTriggered: root.alertVisible = false }

  Timer {
    id: blink
    interval: 260; repeat: true
    running: root.alertVisible
    property bool on: true
    onTriggered: on = !on
    onRunningChanged: on = true
  }

  Variants {
    model: root.alertVisible ? Quickshell.screens : []

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors { top: true; left: true; right: true }
      margins.top: Math.round(modelData.height * 0.18)
      implicitHeight: 150
      color: "transparent"

      WlrLayershell.namespace: "evangelion-internal-power"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      readonly property color c: root.internal ? root.amber : root.lime

      Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 760)
        height: 130
        color: Qt.rgba(0.03, 0.02, 0.015, 0.92)
        border.color: c
        border.width: 3
        opacity: blink.on ? 1 : 0.55

        // bandes d'avertissement
        Row {
          anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
          anchors.margins: 3
          height: 10; clip: true; spacing: 10
          Repeater { model: 60; Rectangle { width: 10; height: 10; color: c; rotation: 0 } }
        }
        Row {
          anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
          anchors.margins: 3
          height: 10; clip: true; spacing: 10
          Repeater { model: 60; Rectangle { width: 10; height: 10; color: c } }
        }

        Column {
          anchors.centerIn: parent
          spacing: 4
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.internal ? "内部電源に切り替わりました" : "外部電源 接続"
            color: c
            font.family: "Noto Serif CJK JP"
            font.weight: Font.Black
            font.pixelSize: 40
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
              if (!root.internal) return "UMBILICAL CABLE CONNECTED — EXTERNAL POWER SUPPLY"
              var est = Countdown.estimateSeconds(root.device)
              return "SWITCHED TO INTERNAL POWER — 活動限界まで "
                     + (est > 0 ? Countdown.clock(est * 1000) : "--:--:--")
            }
            color: c
            font.family: "monospace"
            font.pixelSize: 15
            font.letterSpacing: 2
          }
        }
      }
    }
  }
}
