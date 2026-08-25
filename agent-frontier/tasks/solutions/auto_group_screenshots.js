function screenshotNames(files) {
  return files
    .filter(function (f) { return f.toLowerCase().indexOf('screenshot') === 0; })
    .sort();
}
