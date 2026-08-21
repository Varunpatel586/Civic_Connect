/**
 * Ward derivation.
 *
 * There is no ward registry behind this — the locality from the geocoded
 * address stands in for one. That is honest about what the data supports: the
 * app knows where a complaint is, not which administrative body owns it. Swap
 * this for a real boundary lookup when one is available; every caller goes
 * through `wardFromAddress`, so nothing else has to change.
 *
 * Mirrors `ComplaintReference.locality` in `lib/utils/complaint_reference.dart`.
 */

/**
 * Addresses are built as `street, locality, postalCode, state, country`, so the
 * second component is the locality.
 *
 * @returns {string|null} The ward name, or null when the address cannot supply one.
 */
function wardFromAddress(address) {
  if (!address || typeof address !== 'string') return null;

  const parts = address
    .split(',')
    .map((part) => part.trim())
    .filter((part) => part.length > 0 && part.toLowerCase() !== 'null');

  if (parts.length < 2) return null;
  return parts[1];
}

/**
 * Whether an officer may act on complaints in a given ward.
 *
 * An officer with no wards assigned is treated as having authority everywhere.
 * That keeps existing accounts working and makes the restriction opt-in, which
 * is the right default for a system where locking the wrong person out is worse
 * than letting the right person see too much.
 */
function officerCoversWard(officerWards, ward) {
  if (!Array.isArray(officerWards) || officerWards.length === 0) return true;
  if (!ward) return false;
  return officerWards.some(
    (assigned) => assigned.toLowerCase() === ward.toLowerCase()
  );
}

/**
 * A Mongo filter restricting a query to an officer's wards.
 * Empty object when the officer covers everything.
 */
function wardFilter(officerWards) {
  if (!Array.isArray(officerWards) || officerWards.length === 0) return {};
  return {
    ward: { $in: officerWards.map((w) => new RegExp(`^${escapeRegex(w)}$`, 'i')) },
  };
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

module.exports = { wardFromAddress, officerCoversWard, wardFilter };
