function romanToInt(s) {
  var map = { I: 1, V: 5, X: 10, L: 50, C: 100, D: 500, M: 1000 };
  var total = 0;
  for (var i = 0; i < s.length; i++) {
    var cur = map[s[i]];
    var next = map[s[i + 1]] || 0;
    if (cur < next) total -= cur; else total += cur;
  }
  return total;
}
