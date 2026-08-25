// BROKEN: does not strip punctuation/spaces or normalise case.
function isPalindrome(s) {
  return s === s.split('').reverse().join('');
}
