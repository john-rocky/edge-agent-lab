// BROKEN: always adds, ignoring the subtractive rule (IV -> 6, not 4).
function romanToInt(s) {
  var map = { I: 1, V: 5, X: 10, L: 50, C: 100, D: 500, M: 1000 };
  var total = 0;
  for (var i = 0; i < s.length; i++) total += map[s[i]];
  return total;
}
