import QtQuick

// Un chiffre sept segments, segments hexagonaux inclinés, avec les segments
// éteints laissés en fantôme comme sur l'afficheur de la NERV.
Canvas {
  id: root

  property int digit: -1          // -1 = vide
  property color litColor: "#FF8A1F"
  property color ghostColor: Qt.rgba(litColor.r, litColor.g, litColor.b, 0.08)
  property real thickness: Math.max(2, width * 0.17)
  property real slant: 0.12        // inclinaison vers la droite

  readonly property var map: [
    0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F
  ]

  implicitWidth: 28
  implicitHeight: 48

  onDigitChanged: requestPaint()
  onLitColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var w = width, h = height, t = thickness, g = t * 0.18
    var sl = slant
    var bits = digit >= 0 && digit <= 9 ? map[digit] : 0
    var mid = h / 2

    function px(x, y) { return [x + (h - y) * sl - h * sl * 0.5, y] }

    function horiz(y) {
      var x0 = t * 0.5 + g, x1 = w - t * 0.5 - g, hh = t / 2
      return [px(x0, y), px(x0 + hh, y - hh), px(x1 - hh, y - hh), px(x1, y), px(x1 - hh, y + hh), px(x0 + hh, y + hh)]
    }
    function vert(x, y0, y1) {
      var a = y0 + g, b = y1 - g, hw = t / 2
      return [px(x, a), px(x + hw, a + hw), px(x + hw, b - hw), px(x, b), px(x - hw, b - hw), px(x - hw, a + hw)]
    }

    var top = t / 2, bot = h - t / 2, left = t / 2, right = w - t / 2
    var segs = [
      horiz(top),               // a
      vert(right, top, mid),    // b
      vert(right, mid, bot),    // c
      horiz(bot),               // d
      vert(left, mid, bot),     // e
      vert(left, top, mid),     // f
      horiz(mid)                // g
    ]

    for (var i = 0; i < 7; i++) {
      var on = (bits >> i) & 1
      ctx.fillStyle = on ? litColor : ghostColor
      ctx.beginPath()
      var p = segs[i]
      ctx.moveTo(p[0][0], p[0][1])
      for (var k = 1; k < p.length; k++) ctx.lineTo(p[k][0], p[k][1])
      ctx.closePath()
      ctx.fill()
    }
  }
}
