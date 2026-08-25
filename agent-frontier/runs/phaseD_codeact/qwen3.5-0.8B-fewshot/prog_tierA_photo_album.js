var NOW = new Date().toISOString();
var TIMEZONE = "UTC";

function notes_search({ query }) {
  var hits = [];
  var q = query.toLowerCase();
  var tags = [];
  var kind = [];
  var docId = null;

  for (var i = 0; i < 100; i++) {
    var doc = notes_get({ id: i });
    if (doc) {
      tags.push(doc.tags);
      kind.push(doc.kind);
      docId = doc.id;
    }
  }

  if (tags.length === 0) {
    return [];
  }

  for (var i = 0; i < tags.length; i++) {
    var tag = tags[i];
    var kind = kind[i];
    if (tag.toLowerCase().includes(q) || kind.toLowerCase().includes(q)) {
      hits.push({ id: docId, tags: tags[i], kind: kind });
    }
  }

  return hits;
}

function notes_get({ id }) {
  var doc = notes_get({ id: id });
  return doc;
}

function notes_create({ title, body }) {
  var album = photos_create_album({ name: title });
  photos_add_to_album({ album, ids: [] });
  console.log("Created album: " + title);
  return album;
}

function photos_create_album({ name }) {
  var album = {
    id: Date.now(),
    name: name,
    photos: []
  };
  photos_add_to_album({ album, ids: [] });
  return album;
}

function photos_add_to_album({ album, ids }) {
  var ids = ids.filter(function(id) {
    return id !== null && id !== undefined;
  });
  if (ids.length === 0) {
    return;
  }
  for (var i = 0; i < ids.length; i++) {
    var photo = photos_get({ id: ids[i] });
    if (photo) {
      album.photos.push(photo);
    }
  }
  console.log("Added " + ids.length + " photos to album: " + album.name);
}

function photos_search({ query }) {
  var hits = notes_search({ query: query });
  if (hits.length === 0) {
    return [];
  }
  return hits;
}

console.log("Receipts album created: Receipts");
console.log("Searching for receipts...");
var receipts = photos_search({ query: "receipt" });
console.log("Found " + receipts.length + " receipt screenshot(s).");