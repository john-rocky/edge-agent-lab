function extractUrls(text) {
  var re = /https?:\/\/\S+/g;
  var m, seen = {}, out = [];
  while ((m = re.exec(text)) !== null) {
    if (!seen.hasOwnProperty(m[0])) { seen[m[0]] = true; out.push(m[0]); }
  }
  return out;
}
