const { NOW, console.log } = window;
const { corpus_search, corpus_read } = window;

// 1. Search for documents containing "Aurora launch"
const searchResults = corpus_search({ query: "Aurora launch" });

// 2. Read the first relevant document to find the launch date and owner
let launchDate = null;
let launchOwner = null;
let securityOwner = null;

if (searchResults.length > 0) {
  const docId = searchResults[0].id;
  const docText = corpus_read({ id: docId });
  
  // Parse the date string (format: "YYYY-MM-DD")
  const dateMatch = docText.match(/(\d{4}-\d{2}-\d{2})/);
  if (dateMatch) {
    launchDate = dateMatch[1];
  }

  // Extract owner names (e.g., "Aurora Systems", "Aurora Inc.")
  const ownerMatch = docText.match(/Aurora\s+(?:Systems|Inc|Corp|Group)\s*(?:,?\s*Owner|Owner of)?\s*(.+?)(?:\s*and\s+)?(?:CEO|Founder|President|Director)\s*(.+?)/i);
  if (ownerMatch) {
    launchOwner = ownerMatch[1].trim();
  }

  // Extract security sign-off owner (e.g., "CISO", "Security Officer", "Compliance Officer")
  const securityMatch = docText.match(/(?:CISO|Security Officer|Compliance Officer|Security Lead|Security Sign-off)\s*(.+?)(?:\s*and\s+)?(?:CEO|Founder|President|Director)\s*(.+?)/i);
  if (securityMatch) {
    securityOwner = securityMatch[1].trim();
  }
}

// 3. Print the answer
console.log(`Aurora Launch Date: ${launchDate}`);
console.log(`Launch Owner: ${launchOwner}`);
console.log(`Security Sign-off Owner: ${securityOwner}`);
console.log(`Documents used: ${searchResults.map(r => r.id).join(", ")}`);