import QtQuick
import QtQuick.Effects
import "Countdown.js" as Countdown

// HH:MM:SS en grand + centièmes en petit, à la manière du chrono
// « 活動限界まで » qui s'affiche quand l'EVA passe sur batterie interne.
Item {
  id: root

  property real milliseconds: 0
  property bool unknown: false
  property color litColor: "#FF8A1F"
  property real digitHeight: 64
  property bool blinkColons: true
  property bool colonOn: true

  readonly property var parts: Countdown.split(milliseconds)
  readonly property real digitWidth: digitHeight * 0.56

  implicitWidth: row.implicitWidth
  implicitHeight: digitHeight

  component Colon: Item {
    property real size: root.digitHeight
    width: size * 0.26
    height: size
    Repeater {
      model: 2
      Rectangle {
        width: parent.size * 0.09; height: width
        x: (parent.width - width) / 2 + (index === 0 ? parent.size * 0.04 : 0)
        y: parent.size * (index === 0 ? 0.28 : 0.66)
        color: root.litColor
        opacity: root.colonOn || !root.blinkColons ? 1 : 0.1
      }
    }
  }

  function digitAt(value, pos) {
    if (root.unknown) return -1
    return pos === 0 ? Math.floor(value / 10) % 10 : value % 10
  }

  Row {
    id: row
    spacing: root.digitHeight * 0.06

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: root.litColor
      shadowBlur: 0.7
      shadowOpacity: 0.85
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      blurMax: 24
    }

    SevenSeg { width: root.digitWidth; height: root.digitHeight; litColor: root.litColor; digit: root.digitAt(root.parts.h, 0) }
    SevenSeg { width: root.digitWidth; height: root.digitHeight; litColor: root.litColor; digit: root.digitAt(root.parts.h, 1) }
    Colon {}
    SevenSeg { width: root.digitWidth; height: root.digitHeight; litColor: root.litColor; digit: root.digitAt(root.parts.m, 0) }
    SevenSeg { width: root.digitWidth; height: root.digitHeight; litColor: root.litColor; digit: root.digitAt(root.parts.m, 1) }
    Colon {}
    SevenSeg { width: root.digitWidth; height: root.digitHeight; litColor: root.litColor; digit: root.digitAt(root.parts.s, 0) }
    SevenSeg { width: root.digitWidth; height: root.digitHeight; litColor: root.litColor; digit: root.digitAt(root.parts.s, 1) }

    Item {
      width: root.digitWidth * 1.35 + root.digitHeight * 0.1
      height: root.digitHeight
      Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        spacing: root.digitHeight * 0.04
        SevenSeg { width: root.digitWidth * 0.6; height: root.digitHeight * 0.55; litColor: root.litColor; digit: root.digitAt(root.parts.cs, 0) }
        SevenSeg { width: root.digitWidth * 0.6; height: root.digitHeight * 0.55; litColor: root.litColor; digit: root.digitAt(root.parts.cs, 1) }
      }
    }
  }
}
