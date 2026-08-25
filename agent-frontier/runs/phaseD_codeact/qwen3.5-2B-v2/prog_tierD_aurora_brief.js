function findLaunchDocs() {
  const results = [];
  for (let i = 0; i < 100; i++) {
    const { id, title, snippet } = corpus_search({ query: "Aurora launch" });
    if (id && title && snippet) {
      results.push({ id, title, snippet });
    }
  }
  return results;
}

function findSecurityDocs() {
  const results = [];
  for (let i = 0; i < 100; i++) {
    const { id, title, snippet } = corpus_search({ query: "Aurora security sign-off" });
    if (id && title && snippet) {
      results.push({ id, title, snippet });
    }
  }
  return results;
}

function findOwnerDocs() {
  const results = [];
  for (let i = 0; i < 100; i++) {
    const { id, title, snippet } = corpus_search({ query: "Aurora launch owner" });
    if (id && title && snippet) {
      results.push({ id, title, snippet });
    }
  }
  return results;
}

function findOwnerSecurityDocs() {
  const results = [];
  for (let i = 0; i < 100; i++) {
    const { id, title, snippet } = corpus_search({ query: "Aurora security sign-off owner" });
    if (id && title && snippet) {
      results.push({ id, title, snippet });
    }
  }
  return results;
}

function findLaunchDate() {
  const results = [];
  for (let i = 0; i < 100; i++) {
    const { id, title, snippet } = corpus_search({ query: "Aurora launch date" });
    if (id && title && snippet) {
      results.push({ id, title, snippet });
    }
  }
  return results;
}

function findOwnerName() {
  const results = [];
  for (let i = 0; i < 100; i++) {
    const { id, title, snippet } = corpus_search({ query: "Aurora launch owner name" });
    if (id && title && snippet) {
      results.push({ id, title, snippet });
    }
  }
  return results;
}

function findOwnerSecurityName() {
  const results = [];
  for (let i = 0; i < 100; i++) {
    const { id, title, snippet } = corpus_search({ query: "Aurora security sign-off owner name" });
    if (id && title && snippet) {
      results.push({ id, title, snippet });
    }
  }
  return results;
}