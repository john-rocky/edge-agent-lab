function twoSum(nums, target) {
  var seen = {};
  for (var i = 0; i < nums.length; i++) {
    var need = target - nums[i];
    if (seen.hasOwnProperty(need)) return [seen[need], i];
    seen[nums[i]] = i;
  }
  return [];
}
