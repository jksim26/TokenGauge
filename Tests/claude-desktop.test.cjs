const test = require('node:test');
const assert = require('node:assert/strict');
const { createCipheriv, createHash, pbkdf2Sync } = require('node:crypto');
const { decryptCookie } = require('../Bridge/claude-desktop.cjs');
function fixture(host = '.claude.ai', version = 24, value = 'test-session-only') {
  const password = 'test-only-safe-storage';
  const key = pbkdf2Sync(password, 'saltysalt', 1003, 16, 'sha1');
  const cipher = createCipheriv('aes-128-cbc', key, Buffer.alloc(16, 32));
  const body = Buffer.concat([version >= 24 ? createHash('sha256').update(host).digest() : Buffer.alloc(0), Buffer.from(value)]);
  return { password, row: { host_key: host, value: '', encrypted: Buffer.concat([Buffer.from('v10'), cipher.update(body), cipher.final()]).toString('hex') } };
}
test('Chromium 24 host-bound Claude cookie decrypts', () => {
  const { password, row } = fixture(); assert.equal(decryptCookie(row, password, 24), 'test-session-only');
});
test('Legacy Claude cookie decrypts without host prefix', () => {
  const { password, row } = fixture('.claude.ai', 23); assert.equal(decryptCookie(row, password, 23), 'test-session-only');
});
test('Other hosts and incorrect host hashes are rejected', () => {
  const { password, row } = fixture();
  assert.throws(() => decryptCookie({ ...row, host_key: 'other.example' }, password, 24), /host mismatch/);
  assert.throws(() => decryptCookie({ ...row, host_key: 'claude.ai' }, password, 24), /integrity check/);
});
test('Unknown cookie encryption is rejected', () => {
  const { password, row } = fixture();
  assert.throws(() => decryptCookie({ ...row, encrypted: Buffer.from('v99unknown').toString('hex') }, password, 24), /unsupported/);
});
