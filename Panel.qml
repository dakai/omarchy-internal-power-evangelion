import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Countdown.js" as Countdown

// Chrono d'alimentation interne façon Evangelion : quand le câble ombilical
// (le secteur) est débranché, le temps de batterie restant défile comme le
// « 活動限界まで あと » de l'EVA. Clic gauche = écran détaillé.
Panel {
  id: root
  moduleName: "evangelion.internal-power"
  ipcTarget: "evangelion.internal-power"

  readonly property color amber: "#FF8A1F"
  readonly property color red: "#FF2A2A"
  readonly property color lime: "#86E33F"
  readonly property color screenBg: "#070504"

  readonly property bool hideOnExternal: setting("hideOnExternal", false) === true
  readonly property int criticalMinutes: Number(setting("criticalMinutes", 10))

  readonly property var device: UPower.displayDevice
  readonly property bool present: !!(device && device.isPresent)
  readonly property bool internal: present && UPower.onBattery
  readonly property real fraction: present ? Math.max(0, Math.min(1, device.percentage)) : 0
  readonly property real watts: present ? Math.abs(Number(device.changeRate || 0)) : 0
  readonly property real timeToFull: present ? Number(device.timeToFull || 0) : 0

  // Compte à rebours lissé : UPower ré-estime toutes les ~30 s, on glisse
  // vers la nouvelle échéance au lieu de sauter d'un coup.
  property real deadline: 0
  property real target: 0
  property real lastTick: 0
  property real remainingMs: 0
  readonly property bool known: internal && deadline > 0
  readonly property bool critical: known && remainingMs < criticalMinutes * 60000
  readonly property bool depleted: known && remainingMs <= 0
  readonly property color stateColor: !internal ? lime : (critical ? red : amber)
  property bool blinkPhase: true

  function updateEstimate() {
    if (!internal) { deadline = 0; target = 0; return }
    var est = Countdown.estimateSeconds(device)
    if (est < 0) return
    var now = Date.now()
    target = now + est * 1000
    if (deadline <= 0 || Math.abs(target - deadline) > Math.max(120000, (deadline - now) * 0.25))
      deadline = target
    tick()
  }

  function tick() {
    var now = Date.now()
    var dt = lastTick > 0 ? Math.min(now - lastTick, 5000) : 0
    lastTick = now
    if (deadline > 0 && target > 0) deadline += (target - deadline) * (1 - Math.exp(-dt / 20000))
    remainingMs = deadline > 0 ? Math.max(0, deadline - now) : 0
  }

  // --- Mode de consommation (power-profiles-daemon via les commandes Omarchy) ---
  readonly property var profileLabels: ({
    "power-saver": { jp: "省電力", en: "POWER-SAVER" },
    "balanced": { jp: "標準", en: "BALANCED" },
    "performance": { jp: "全力", en: "PERFORMANCE" }
  })
  property var profiles: []
  property string activeProfile: ""
  property int profileCursor: -1

  function refreshProfiles() { if (!profilesProc.running) profilesProc.running = true }

  function parseProfiles(raw) {
    var list = [], active = ""
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].trim().split("\t")
      if (!parts[0]) continue
      list.push(parts[0])
      if (parts[1] === "1") active = parts[0]
    }
    if (list.length === 0) return
    profiles = list
    activeProfile = active
  }

  function setProfile(name) {
    if (!name || setProfileProc.running) return
    activeProfile = name
    setProfileProc.command = ["omarchy-powerprofiles-set", internal ? "battery" : "ac", name]
    setProfileProc.running = true
  }

  function cycleProfile() {
    if (profiles.length === 0) return
    var i = profiles.indexOf(activeProfile)
    setProfile(profiles[(i + 1) % profiles.length])
  }

  Process {
    id: profilesProc
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseProfiles(text) }
  }

  Process {
    id: setProfileProc
    onExited: root.refreshProfiles()
  }

  onOpenedChanged: if (opened) { profileCursor = -1; refreshProfiles() }

  onInternalChanged: { deadline = 0; updateEstimate(); profileRefreshDelay.restart() }

  // Omarchy réapplique le profil mémorisé ac/battery au (dé)branchement.
  Timer { id: profileRefreshDelay; interval: 1500; onTriggered: root.refreshProfiles() }
  Component.onCompleted: { updateEstimate(); refreshProfiles() }

  Connections {
    target: root.device
    ignoreUnknownSignals: true
    function onTimeToEmptyChanged() { root.updateEstimate() }
    function onChangeRateChanged() { if (root.deadline <= 0) root.updateEstimate() }
  }

  // 1 Hz dans la barre, ~30 Hz quand l'écran détaillé est ouvert (centièmes).
  Timer {
    interval: root.opened ? 33 : 1000
    running: root.internal
    repeat: true
    onTriggered: { if (root.deadline <= 0) root.updateEstimate(); root.tick() }
  }

  Timer {
    interval: 500
    running: root.critical || (root.opened && root.internal)
    repeat: true
    onTriggered: root.blinkPhase = !root.blinkPhase
    onRunningChanged: if (!running) root.blinkPhase = true
  }

  readonly property bool shown: present && !(hideOnExternal && !internal)
  visible: shown
  implicitWidth: shown ? button.implicitWidth : 0
  implicitHeight: shown ? button.implicitHeight : 0

  onShownChanged: if (!shown) close()

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    foreground: root.stateColor
    useActiveColor: false
    text: {
      if (root.vertical) return root.internal ? "内" : "外"
      return (root.internal ? "内部電源 " : "外部電源 ") + Math.round(root.fraction * 100) + "%"
    }
    dimmed: root.critical && !root.blinkPhase
    tooltipText: (root.internal
      ? "活動限界まで " + (root.known ? Countdown.clock(root.remainingMs) : "--:--:--")
      : "外部電源 — umbilical cable connected")
      + (root.profileLabels[root.activeProfile] ? "\n" + root.profileLabels[root.activeProfile].jp + " " + root.profileLabels[root.activeProfile].en : "")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleProfile()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.shown
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(470))
    contentHeight: panel.fittedContentHeight(screen.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        var n = root.profiles.length
        if (n === 0) return
        if (root.profileCursor < 0) { root.profileCursor = Math.max(0, root.profiles.indexOf(root.activeProfile)); return }
        root.profileCursor = Math.max(0, Math.min(n - 1, root.profileCursor + (dx !== 0 ? dx : dy)))
      }
      onActivateRequested: if (root.profileCursor >= 0) root.setProfile(root.profiles[root.profileCursor])
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Rectangle {
        id: screen
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: body.implicitHeight + Style.space(28)
        color: root.screenBg
        border.color: Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.55)
        border.width: 2

        // Lignes de balayage discrètes
        Column {
          anchors.fill: parent
          anchors.margins: 2
          clip: true
          Repeater {
            model: Math.ceil(screen.height / 4)
            Rectangle { width: screen.width; height: 4; color: index % 2 ? "transparent" : Qt.rgba(1, 1, 1, 0.018) }
          }
        }

        Column {
          id: body
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(14)
          spacing: Style.space(10)

          // --- En-tête : 活動限界まで あと + voyants INTERNAL / EXTERNAL ---
          Item {
            width: parent.width
            implicitHeight: Math.max(titleCol.implicitHeight, lamps.implicitHeight)

            Column {
              id: titleCol
              spacing: 0
              Text {
                text: root.internal ? (root.depleted ? "活動限界" : "活動限界まで あと") : "外部電源 接続中"
                color: root.stateColor
                font.family: "Noto Serif CJK JP"
                font.weight: Font.Black
                font.pixelSize: Style.space(22)
                opacity: root.depleted && !root.blinkPhase ? 0.2 : 1
              }
              Text {
                text: root.internal ? (root.depleted ? "ACTIVITY LIMIT REACHED" : "INTERNAL POWER · ACTIVE TIME REMAINING")
                                    : "UMBILICAL CABLE CONNECTED"
                color: Qt.darker(root.stateColor, 1.25)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.space(10)
                font.letterSpacing: 1.5
              }
            }

            Column {
              id: lamps
              anchors.right: parent.right
              spacing: Style.space(4)
              Repeater {
                model: [
                  { jp: "内部", en: "INTERNAL", on: root.internal, c: root.critical ? root.red : root.amber },
                  { jp: "外部", en: "EXTERNAL", on: !root.internal, c: root.lime }
                ]
                Rectangle {
                  width: Style.space(104); height: Style.space(20)
                  color: modelData.on ? modelData.c : "transparent"
                  border.color: modelData.on ? modelData.c : Qt.rgba(modelData.c.r, modelData.c.g, modelData.c.b, 0.3)
                  border.width: 1
                  Text {
                    anchors.centerIn: parent
                    text: modelData.jp + " " + modelData.en
                    color: modelData.on ? root.screenBg : Qt.rgba(modelData.c.r, modelData.c.g, modelData.c.b, 0.35)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.space(10)
                    font.bold: true
                  }
                }
              }
            }
          }

          // --- Le chrono ---
          Item {
            width: parent.width
            implicitHeight: timer.implicitHeight + Style.space(16)
            TimerDisplay {
              id: timer
              anchors.centerIn: parent
              digitHeight: Style.space(62)
              litColor: root.stateColor
              milliseconds: root.remainingMs
              unknown: !root.known
              colonOn: root.blinkPhase
              blinkColons: root.internal
              opacity: root.depleted && !root.blinkPhase ? 0.25 : 1
            }
          }

          // --- Jauge de charge segmentée ---
          Row {
            width: parent.width
            spacing: Style.space(3)
            Repeater {
              model: 20
              Rectangle {
                width: (body.width - Style.space(3) * 19) / 20
                height: Style.space(8)
                readonly property bool lit: index < Math.round(root.fraction * 20)
                color: lit ? root.stateColor : Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.1)
              }
            }
          }

          // --- Mode de consommation ---
          Column {
            width: parent.width
            spacing: Style.space(5)
            visible: root.profiles.length > 0

            Text {
              text: "出力制御 · POWER MODE"
              color: Qt.darker(root.stateColor, 1.25)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.space(10)
              font.letterSpacing: 1.5
            }

            Row {
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: root.profiles
                Rectangle {
                  id: modeBtn
                  readonly property bool active: modelData === root.activeProfile
                  readonly property bool cursor: index === root.profileCursor
                  readonly property var label: root.profileLabels[modelData] || { jp: modelData, en: "" }
                  width: (body.width - Style.space(6) * (root.profiles.length - 1)) / root.profiles.length
                  height: Style.space(40)
                  color: active ? root.stateColor : (modeMouse.containsMouse ? Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.12) : "transparent")
                  border.color: active || cursor ? root.stateColor : Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.35)
                  border.width: cursor ? 2 : 1

                  Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: modeBtn.label.jp
                      color: modeBtn.active ? root.screenBg : root.stateColor
                      font.family: "Noto Sans CJK JP"
                      font.weight: Font.Black
                      font.pixelSize: Style.space(14)
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: modeBtn.label.en
                      color: modeBtn.active ? root.screenBg : Qt.darker(root.stateColor, 1.3)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      font.letterSpacing: 1
                    }
                  }

                  MouseArea {
                    id: modeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setProfile(modelData)
                  }
                }
              }
            }
          }

          Item {
            width: parent.width
            implicitHeight: leftInfo.implicitHeight
            Text {
              id: leftInfo
              text: "主電源 " + Math.round(root.fraction * 100) + "%"
                    + (root.internal ? "" : (root.timeToFull > 0 ? "  ·  充電完了まで " + Countdown.clock(root.timeToFull * 1000) : ""))
              color: root.stateColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.space(12)
            }
            Text {
              anchors.right: parent.right
              text: (root.internal ? "消費 " : "供給 ") + root.watts.toFixed(1) + " W"
              color: root.stateColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.space(12)
            }
          }
        }
      }
    }
  }
}
