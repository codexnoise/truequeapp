/**
 * Unit tests for password reset cooldown helpers (throttlePasswordResetEmail).
 * Uses Node.js built-in assert module (no extra dependencies).
 *
 * Run: node test_password_reset_cooldown.js   (from functions/)
 */

const assert = require('assert');
const { RESET_COOLDOWN_MS, normalizeEmail, cooldownRemainingMs } = require('./password_reset_cooldown');

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

console.log('\nnormalizeEmail');

test('minúsculas y sin espacios', () => {
  assert.strictEqual(normalizeEmail('  Ana.Lopez@Gmail.COM '), 'ana.lopez@gmail.com');
});

test('rechaza valores que no son un correo', () => {
  assert.strictEqual(normalizeEmail(''), null);
  assert.strictEqual(normalizeEmail('sin-arroba'), null);
  assert.strictEqual(normalizeEmail('a@b'), null);
  assert.strictEqual(normalizeEmail('a b@x.com'), null);
  assert.strictEqual(normalizeEmail(`${'a'.repeat(250)}@x.com`), null);
  assert.strictEqual(normalizeEmail(undefined), null);
  assert.strictEqual(normalizeEmail({ email: 'a@x.com' }), null);
});

console.log('\ncooldownRemainingMs');

const now = 1_800_000_000_000;

test('sin solicitud previa → permitido', () => {
  assert.strictEqual(cooldownRemainingMs(null, now), 0);
  assert.strictEqual(cooldownRemainingMs(undefined, now), 0);
});

test('solicitud de hace 10 min → faltan 50 min', () => {
  assert.strictEqual(cooldownRemainingMs(now - 10 * 60 * 1000, now), 50 * 60 * 1000);
});

test('justo a la hora → permitido', () => {
  assert.strictEqual(cooldownRemainingMs(now - RESET_COOLDOWN_MS, now), 0);
});

test('hace más de una hora → permitido', () => {
  assert.strictEqual(cooldownRemainingMs(now - 2 * RESET_COOLDOWN_MS, now), 0);
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
