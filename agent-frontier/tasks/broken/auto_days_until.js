// BROKEN: operands swapped, so the sign of the result is inverted.
function daysUntil(fromISO, toISO) {
  function toUTC(d) {
    var p = d.split('-');
    return Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  }
  return Math.round((toUTC(fromISO) - toUTC(toISO)) / 86400000);
}
