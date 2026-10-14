/**
 * Unit tests for new-item notification logic.
 * Uses Node.js built-in assert module (no extra dependencies).
 *
 * Run: node test_new_item_recipients.js   (from functions/)
 */

const assert = require('assert');
const { selectNewItemRecipients, buildNewItemText } = require('./new_item_recipients');

let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✅ ${name}`);
  } catch (e) {
    failed++;
    failures.push({ name, error: e.message });
    console.log(`  ❌ ${name}: ${e.message}`);
  }
}

console.log('\nselectNewItemRecipients');

test('excluye al autor', () => {
  const users = [
    { uid: 'author', fcmToken: 'tA', notifyNewItems: true },
    { uid: 'u1', fcmToken: 't1' },
  ];
  assert.deepStrictEqual(selectNewItemRecipients(users, 'author'), [{ uid: 'u1', token: 't1' }]);
});

test('excluye usuarios sin token o con token vacío', () => {
  const users = [
    { uid: 'u1' },
    { uid: 'u2', fcmToken: '' },
    { uid: 'u3', fcmToken: null },
    { uid: 'u4', fcmToken: 't4' },
  ];
  assert.deepStrictEqual(selectNewItemRecipients(users, 'x'), [{ uid: 'u4', token: 't4' }]);
});

test('excluye notifyNewItems === false; incluye true y ausente', () => {
  const users = [
    { uid: 'off', fcmToken: 't0', notifyNewItems: false },
    { uid: 'on', fcmToken: 't1', notifyNewItems: true },
    { uid: 'missing', fcmToken: 't2' },
  ];
  assert.deepStrictEqual(selectNewItemRecipients(users, 'x'), [
    { uid: 'on', token: 't1' },
    { uid: 'missing', token: 't2' },
  ]);
});

test('deduplica tokens repetidos (se queda con el primero)', () => {
  const users = [
    { uid: 'a', fcmToken: 'same' },
    { uid: 'b', fcmToken: 'same' },
  ];
  assert.deepStrictEqual(selectNewItemRecipients(users, 'x'), [{ uid: 'a', token: 'same' }]);
});

test('el autor con el mismo token que otro usuario no deja pasar ese token', () => {
  const users = [
    { uid: 'author', fcmToken: 'shared' },
    { uid: 'other', fcmToken: 'shared' },
  ];
  assert.deepStrictEqual(selectNewItemRecipients(users, 'author'), []);
});

console.log('\nbuildNewItemText');

test('trueque: categoría conocida + Busca', () => {
  assert.deepStrictEqual(
    buildNewItemText({ title: 'Cámara', categoryId: 'tech', desiredItem: 'Un libro' }),
    { title: 'Nuevo artículo: Cámara', body: 'Tecnología · Busca: Un libro' },
  );
});

test('donación', () => {
  assert.deepStrictEqual(
    buildNewItemText({ title: 'Taza', categoryId: 'home', desiredItem: 'Donation' }),
    { title: 'Nuevo artículo: Taza', body: 'Hogar · Donación' },
  );
});

test('categoría desconocida cae en General', () => {
  assert.deepStrictEqual(
    buildNewItemText({ title: 'X', categoryId: 'nope', desiredItem: 'Y' }),
    { title: 'Nuevo artículo: X', body: 'General · Busca: Y' },
  );
});

console.log('\n' + '='.repeat(60));
console.log(`\n📊 Results: ${passed} passed, ${failed} failed, ${passed + failed} total\n`);
if (failures.length > 0) {
  console.log('❌ Failures:');
  failures.forEach(f => console.log(`   - ${f.name}: ${f.error}`));
  process.exit(1);
} else {
  console.log('✅ All tests passed!\n');
  process.exit(0);
}
