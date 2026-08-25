var hits = corpus_search({ query: "Aurora launch" });
if (hits.length === 0) {
  console.log("No documents found for 'Aurora launch'.");
} else {
  var launchDate = "";
  var owner = "";
  var securityOwner = "";
  var docIds = [];

  for (var i = 0; i < hits.length; i++) {
    var doc = corpus_read({ id: hits[i].id });
    docIds.push(doc.id);
    if (doc.body.toLowerCase().includes("launch") && doc.body.toLowerCase().includes("aurora")) {
      launchDate = doc.body;
    }
    if (doc.body.toLowerCase().includes("owns") && doc.body.toLowerCase().includes("aurora")) {
      owner = doc.body;
    }
    if (doc.body.toLowerCase().includes("security") && doc.body.toLowerCase().includes("sign-off")) {
      securityOwner = doc.body;
    }
  }

  var answer = "";
  if (launchDate) {
    answer += "Aurora launches on " + launchDate + ".";
  }
  if (owner) {
    answer += "The launch is owned by " + owner + ".";
  }
  if (securityOwner) {
    answer += "The security sign-off is owned by " + securityOwner + ".";
  }

  console.log(answer);
}