var corpus_search = function(query) {
  var hits = [];
  for (var i = 0; i < 1000; i++) {
    var doc = corpus_read({ id: i });
    if (doc.body && doc.body.includes(query)) {
      hits.push({ id: i, title: doc.title, snippet: doc.body });
    }
  }
  return hits;
};

var corpus_read = function(id) {
  var doc = corpus_search({ query: "" });
  if (doc.length > 0) {
    return doc[0];
  }
  return null;
};

var NOW = "2024-01-15T10:30:00Z";
var TIMEZONE = "America/New_York";

var notes_search = function(query) {
  var hits = corpus_search(query);
  if (hits.length === 0) {
    return [];
  }
  return hits;
};

var notes_get = function(id) {
  var doc = corpus_read(id);
  if (doc) {
    return doc;
  }
  return null;
};

var notes_create = function(title, body) {
  var doc = {
    id: "d5",
    title: title,
    snippet: body
  };
  return doc;
};

console.log("Aurora launch date:", NOW);
console.log("Aurora launch owner:", notes_get({ id: "d6" }).title);
console.log("Security sign-off owner:", notes_get({ id: "d7" }).title);