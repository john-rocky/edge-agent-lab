function daysUntil(fromISO, toISO) {
  function toUTC(d) {
    var p = d.split('-');
    return Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  }
  return Math.round((toUTC(toISO) - toUTC(fromISO)) / 86400000);
}
