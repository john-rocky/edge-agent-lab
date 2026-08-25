// BROKEN: returns raw matches without de-duplicating (repeats stay in).
function extractUrls(text) {
  return text.match(/https?:\/\/\S+/g) || [];
}
