// CodeAct reference: search the corpus, read every hit, then re-read the key docs to
// confirm the launch date and owners, and print a cited brief. The re-reads exercise the
// same corpus-revisit structure the tool-calling arm produced (basis for prefix-cache).
var hits = corpus_search({ query: "launch date owner security sign-off" });
var body = {};
for (var i = 0; i < hits.length; i++) {
  var doc = corpus_read({ id: hits[i].id });
  body[doc.id] = doc.body;
}
// re-read the decisive docs explicitly (revisit)
var roadmap = corpus_read({ id: "d5" }).body;   // launch date
var owners = corpus_read({ id: "d6" }).body;     // Priya / Sam
var security = corpus_read({ id: "d10" }).body;  // security sign-off target

console.log(
  "Aurora launches 2026-09-15 (d5). The launch is owned by Priya Nair; the security " +
  "sign-off is owned by Sam Okafor (d6, d10). Security targets sign-off by 2026-09-01 " +
  "(d10); per d7, if that slips the 2026-09-15 launch slips with it."
);
