function splitBill(total, people) {
  return Math.round((total / people) * 100) / 100;
}
