/**
 * Response-window policy.
 *
 * The server is the source of truth: every issue payload carries a computed
 * `due_at`, and the Flutter client formats that rather than recomputing the
 * window. `lib/utils/sla.dart` keeps a matching table only as an offline
 * fallback for payloads that predate this field — if you change a number here,
 * change it there too.
 *
 * These are policy, not physics. Live safety and supply failures get a short
 * window; wear-and-tear gets a long one. Retune to whichever corporation you
 * are pitching.
 */
const WINDOW_DAYS = {
  water: 2,
  electricity: 2,
  street_light: 3,
  garbage: 3,
  drainage: 5,
  pothole: 7,
  road: 10,
  other: 7,
};

const DEFAULT_WINDOW_DAYS = 7;

const TERMINAL_STATUSES = ['Resolved', 'Rejected'];

function windowFor(category) {
  if (!category) return DEFAULT_WINDOW_DAYS;
  return WINDOW_DAYS[String(category).toLowerCase()] ?? DEFAULT_WINDOW_DAYS;
}

/** The deadline a complaint is measured against. */
function dueDate(issue) {
  const filed = issue.createdAt ? new Date(issue.createdAt) : new Date();
  return new Date(filed.getTime() + windowFor(issue.category) * 86400000);
}

function isClosed(issue) {
  return TERMINAL_STATUSES.includes(issue.status);
}

/** Open complaints that have passed their deadline. Closed work never counts. */
function isOverdue(issue, now = new Date()) {
  if (isClosed(issue)) return false;
  return dueDate(issue).getTime() < now.getTime();
}

module.exports = {
  WINDOW_DAYS,
  DEFAULT_WINDOW_DAYS,
  TERMINAL_STATUSES,
  windowFor,
  dueDate,
  isClosed,
  isOverdue,
};
