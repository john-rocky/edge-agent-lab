// CodeAct reference: find receipt screenshots, create the album, add them. One round.
var hits = photos_search({ query: "receipt screenshot" });
var ids = hits.map(function (p) { return p.id; });
photos_create_album({ name: "Receipts" });
photos_add_to_album({ album: "Receipts", ids: ids });
console.log("Added " + ids.length + " receipt screenshots to Receipts: " + ids.join(", "));
