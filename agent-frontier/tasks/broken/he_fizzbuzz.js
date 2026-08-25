// BROKEN: checks %3 and %5 before %15, so multiples of 15 become "Fizz",
// never "FizzBuzz".
function fizzbuzz(n) {
  var out = [];
  for (var i = 1; i <= n; i++) {
    if (i % 3 === 0) out.push('Fizz');
    else if (i % 5 === 0) out.push('Buzz');
    else if (i % 15 === 0) out.push('FizzBuzz');
    else out.push(String(i));
  }
  return out;
}
