/**
 * Server-side complaint references.
 *
 * Mirrors `ComplaintReference` in `lib/utils/complaint_reference.dart` — the
 * client derives the same string from the same three inputs, so a reference
 * quoted in a notification matches the one on screen without storing a field.
 * If you change the format here, change it there too.
 */

const STATE_CODES = {
  'andhra pradesh': 'AP', 'arunachal pradesh': 'AR', 'assam': 'AS',
  'bihar': 'BR', 'chhattisgarh': 'CG', 'goa': 'GA', 'gujarat': 'GJ',
  'haryana': 'HR', 'himachal pradesh': 'HP', 'jharkhand': 'JH',
  'karnataka': 'KA', 'kerala': 'KL', 'madhya pradesh': 'MP',
  'maharashtra': 'MH', 'manipur': 'MN', 'meghalaya': 'ML', 'mizoram': 'MZ',
  'nagaland': 'NL', 'odisha': 'OD', 'punjab': 'PB', 'rajasthan': 'RJ',
  'sikkim': 'SK', 'tamil nadu': 'TN', 'telangana': 'TS', 'tripura': 'TR',
  'uttar pradesh': 'UP', 'uttarakhand': 'UK', 'west bengal': 'WB',
  'delhi': 'DL', 'jammu and kashmir': 'JK', 'ladakh': 'LA',
  'puducherry': 'PY', 'chandigarh': 'CH',
};

/** State code parsed out of the address, or `IN` when none is recognised. */
function stateCode(address) {
  if (!address) return 'IN';
  const haystack = String(address).toLowerCase();
  for (const [name, code] of Object.entries(STATE_CODES)) {
    if (haystack.includes(name)) return code;
  }
  return 'IN';
}

/**
 * Five stable digits from the record id.
 *
 * ObjectIds end in a counter, so the trailing hex is short and well spread.
 * The Dart side falls back to a string hash for non-hex ids, which only its
 * offline sample rows produce; every id reaching this function is a real
 * ObjectId, so the hex path is the only one that runs here.
 */
function sequence(id) {
  const s = String(id || '');
  if (s.length === 0) return '00000';
  const tail = s.length >= 6 ? s.slice(-6) : s;
  const parsed = Number.parseInt(tail, 16);
  const value = Number.isNaN(parsed) ? 0 : parsed;
  return String(value % 100000).padStart(5, '0');
}

/** The full reference, e.g. `CC-2026-GJ-04821`. */
function referenceFor(issue) {
  if (!issue) return '';
  const filed = issue.createdAt ? new Date(issue.createdAt) : new Date();
  return `CC-${filed.getFullYear()}-${stateCode(issue.address)}-${sequence(issue._id)}`;
}

module.exports = { referenceFor, stateCode, sequence };
