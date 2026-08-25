// BROKEN: does not round to 2 decimals (100/3 -> 33.333..., not 33.33).
function splitBill(total, people) {
  return total / people;
}
