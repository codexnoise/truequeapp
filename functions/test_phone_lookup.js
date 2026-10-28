/**
 * Unit tests for phone lookup helpers (findEmailByPhone).
 * Uses Node.js built-in assert module (no extra dependencies).
 *
 * Run: node test_phone_lookup.js   (from functions/)
 */

const assert = require('assert');
const { maskEmail, normalizePhone } = require('./phone_lookup');

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

console.log('\nmaskEmail');

test('deja la primera y la última letra del usuario (igual que la app)', () => {
  assert.strictEqual(maskEmail('andrea.lopez@gmail.com'), 'a***z@gmail.com');
});

test('usuario de una letra', () => {
  assert.strictEqual(maskEmail('a@x.com'), 'a***@x.com');
});

test('email inválido, vacío o ausente → null', () => {
  assert.strictEqual(maskEmail('sin-arroba'), null);
  assert.strictEqual(maskEmail('@x.com'), null);
  assert.strictEqual(maskEmail(''), null);
  assert.strictEqual(maskEmail(undefined), null);
  assert.strictEqual(maskEmail(42), null);
});

console.log('\nnormalizePhone');

test('acepta el formato guardado por la app (0 + 9 dígitos)', () => {
  assert.strictEqual(normalizePhone('0983853525'), '0983853525');
});

test('recorta espacios', () => {
  assert.strictEqual(normalizePhone('  0983853525 '), '0983853525');
});

test('rechaza valores que no son un teléfono', () => {
  assert.strictEqual(normalizePhone(''), null);
  assert.strictEqual(normalizePhone('abc'), null);
  assert.strictEqual(normalizePhone('12'), null);
  assert.strictEqual(normalizePhone('1'.repeat(20)), null);
  assert.strictEqual(normalizePhone(undefined), null);
  assert.strictEqual(normalizePhone({ phone: '0983853525' }), null);
});

console.log(`\n📊 Results: ${passed} passed, ${failed} failed, ${passed + failed} total`);
if (failed > 0) {
  console.log('\n❌ Failures:');
  failures.forEach(f => console.log(`  - ${f.name}: ${f.error}`));
  process.exit(1);
} else {
  console.log('✅ All tests passed!\n');
  process.exit(0);
}
