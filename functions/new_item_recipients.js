/**
 * Pure helpers for the notifyNewItem Cloud Function (no Firebase imports,
 * so they can be unit-tested with plain Node).
 */

// Mirror of lib/features/home/presentation/widgets/category_constants.dart
const CATEGORY_NAMES = {
  tech: 'Tecnología',
  fashion: 'Moda',
  home: 'Hogar',
  books: 'Libros',
  music: 'Música',
  general: 'General',
};

/**
 * @param {Array<{uid: string, fcmToken?: string|null, notifyNewItems?: boolean}>} users
 * @param {string} authorId
 * @returns {Array<{uid: string, token: string}>} one entry per distinct token
 */
function selectNewItemRecipients(users, authorId) {
  const authorTokens = new Set(
    users.filter(u => u.uid === authorId && u.fcmToken).map(u => u.fcmToken),
  );
  const seen = new Set();
  const recipients = [];
  for (const user of users) {
    if (user.uid === authorId) continue;
    if (!user.fcmToken) continue;
    if (user.notifyNewItems === false) continue;
    if (authorTokens.has(user.fcmToken)) continue;
    if (seen.has(user.fcmToken)) continue;
    seen.add(user.fcmToken);
    recipients.push({ uid: user.uid, token: user.fcmToken });
  }
  return recipients;
}

/**
 * @param {{title: string, categoryId: string, desiredItem: string}} item
 * @returns {{title: string, body: string}}
 */
function buildNewItemText(item) {
  const category = CATEGORY_NAMES[item.categoryId] || 'General';
  const wanted = item.desiredItem === 'Donation' ? 'Donación' : `Busca: ${item.desiredItem}`;
  return {
    title: `Nuevo artículo: ${item.title}`,
    body: `${category} · ${wanted}`,
  };
}

module.exports = { selectNewItemRecipients, buildNewItemText, CATEGORY_NAMES };
