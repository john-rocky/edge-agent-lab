function isValidTimestamp(ts) {
  if (!ts || typeof ts !== 'string') return false;
  const date = new Date(ts);
  return !isNaN(date.getTime());
}

// Helper to check if a string is a valid IANA timezone
function isValidTimezone(tz) {
  if (!tz || typeof tz !== 'string') return false;
  return tz === 'UTC' || tz === 'America/New_York' || tz === 'Europe/London' || tz === 'Asia/Tokyo';
}

// Helper to check if a string is a valid photo ID (simple regex)
function isValidPhotoId(id) {
  if (!id || typeof id !== 'string') return false;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id);
}

// Helper to check if a string is a valid tag (simple regex)
function isValidTag(tag) {
  if (!tag || typeof tag !== 'string') return false;
  return /^[a-zA-Z0-9\s\-_]+$/.test(tag);
}

// Helper to check if a string is a valid kind (simple regex)
function isValidKind(kind) {
  if (!kind || typeof kind !== 'string') return false;
  return /^(Receipt|Invoice|Screenshot|Receipt_Screenshot)$/.test(kind);
}

// Helper to check if a string is a valid album name
function isValidAlbumName(name) {
  if (!name || typeof name !== 'string') return false;
  return /^[a-zA-Z0-9\s\-_]+$/.test(name);
}

// Helper to check if a string is a valid date format (YYYY-MM-DD)
function isValidDate(dateStr) {
  if (!dateStr || typeof dateStr !== 'string') return false;
  const d = new Date(dateStr);
  return !isNaN(d.getTime());
}

// Helper to check if a string is a valid date format (YYYY-MM-DDTHH:mm:ss)
function isValidDateWithTime(dateStr) {
  if (!dateStr || typeof dateStr !== 'string') return false;
  const d = new Date(dateStr);
  return !isNaN(d.getTime());
}

// Helper to check if a string is a valid date format (YYYY-MM-DD)
function isValidDateOnly(dateStr) {
  if (!dateStr || typeof dateStr !== 'string') return false;
  const d = new Date(dateStr);
  return !isNaN(d.getTime());
}

// Helper to check if a string is a valid date format (YYYY-MM-DDTHH:mm:ss)
function isValidDateWithTimeOnly(dateStr) {
  if (!dateStr || typeof dateStr !== 'string') return false;
  const d = new Date(dateStr);
  return !isNaN(d.getTime());
}