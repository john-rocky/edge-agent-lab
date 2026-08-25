var hits = photos_search({ query: "receipt" });
if (hits.length === 0) {
  console.log("No receipt screenshots found.");
} else {
  var receipt_photos = [];
  for (var i = 0; i < hits.length; i++) {
    var photo = photos_get({ id: hits[i].id });
    if (photo.kind === "receipt") {
      receipt_photos.push(photo);
    }
  }
  photos_create_album({ name: "Receipts" });
  for (var i = 0; i < receipt_photos.length; i++) {
    photos_add_to_album({ album: { id: "receipts_album" }, ids: receipt_photos[i].id });
  }
  console.log("Added " + receipt_photos.length + " receipt screenshots to 'Receipts' album.");
}