/**
 * Pure helpers for throttlePasswordResetEmail (one reset email per hour per address).
 * No Firebase imports, so they can be unit-tested with plain Node.
 */

// Firebase Auth reset links live 1 hour (fixed by Firebase); while the last one
// is still valid we don't send another.
const RESET_COOLDOWN_MS = 60 * 60 * 1000;

/**
 * Normalizes the email so "Ana@X.com " and "ana@x.com" share
 * the same cooldown.
 * @param {unknown} email
 * @returns {string|null} lowercased trimmed email, or null if invalid
 */
function normalizeEmail(email) {
  if (typeof email !== 'string') return null;
  const trimmed = email.trim().toLowerCase();
  if (trimmed.length > 254) return null;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed) ? trimmed : null;
}

/**
 * Milliseconds left until a new reset email may be sent.
 * @param {number|null|undefined} lastRequestedAtMs previous request, epoch ms
 * @param {number} nowMs
 * @returns {number} 0 if allowed now
 */
function cooldownRemainingMs(lastRequestedAtMs, nowMs) {
  if (typeof lastRequestedAtMs !== 'number' || !Number.isFinite(lastRequestedAtMs)) return 0;
  const remaining = lastRequestedAtMs + RESET_COOLDOWN_MS - nowMs;
  return remaining > 0 ? remaining : 0;
}

module.exports = { RESET_COOLDOWN_MS, normalizeEmail, cooldownRemainingMs };
