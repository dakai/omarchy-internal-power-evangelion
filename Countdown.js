.pragma library

// Secondes restantes estimées par UPower, avec repli sur énergie / débit
// quand UPower n'a pas encore d'estimation (juste après le débranchement).
function estimateSeconds(device) {
  if (!device || !device.isPresent) return -1
  var tte = Number(device.timeToEmpty || 0)
  if (tte > 0) return tte
  var rate = Number(device.changeRate || 0)
  var energy = Number(device.energy || 0)
  if (rate > 0.3 && energy > 0) return energy / rate * 3600
  return -1
}

function pad(n) {
  return n < 10 ? "0" + n : String(n)
}

// ms -> { h, m, s, cs } bornés à 99:59:59.99
function split(ms) {
  ms = Math.max(0, Math.min(ms, 99 * 3600000 + 59 * 60000 + 59999))
  var total = Math.floor(ms / 1000)
  return {
    h: Math.floor(total / 3600),
    m: Math.floor(total / 60) % 60,
    s: total % 60,
    cs: Math.floor(ms / 10) % 100
  }
}

function clock(ms) {
  var t = split(ms)
  return pad(t.h) + ":" + pad(t.m) + ":" + pad(t.s)
}
