/**
 * Pure helpers for findEmailByPhone (password recovery hint).
 * No Firebase imports, so they can be unit-tested with plain Node.
 */

/**
 * Masks an email the same way the app always has: first and last letter of
 * the local part, "***" in between ("andrea@x.com" → "a***a@x.com").
 * @param {unknown} email
 * @returns {string|null} null if it isn't a usable email
 */
function maskEmail(email) {
  if (typeof email !== 'string') return null;
  const at = email.indexOf('@');
  if (at < 1) return null;
  const name = email.slice(0, at);
  const domain = email.slice(at + 1);
  if (!domain) return null;
  const masked = name.length > 1 ? `${name[0]}***${name[name.length - 1]}` : `${name[0]}***`;
  return `${masked}@${domain}`;
}

/**
 * Validates the phone sent by the app (stored as "0" + 9 digits in Ecuador,
 * but kept generic: 6–15 digits, optional leading "+").
 * @param {unknown} phone
 * @returns {string|null} trimmed phone, or null if invalid
 */
function normalizePhone(phone) {
  if (typeof phone !== 'string') return null;
  const trimmed = phone.trim();
  return /^\+?\d{6,15}$/.test(trimmed) ? trimmed : null;
}

module.exports = { maskEmail, normalizePhone };
