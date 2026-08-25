// BROKEN: case-sensitive match (misses "screenshot_home.jpg") and never sorts.
function screenshotNames(files) {
  return files.filter(function (f) { return f.indexOf('Screenshot') === 0; });
}
