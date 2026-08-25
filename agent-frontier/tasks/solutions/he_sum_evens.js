function sumEvens(nums) {
  return nums.filter(function (n) { return n % 2 === 0; })
             .reduce(function (a, b) { return a + b; }, 0);
}
