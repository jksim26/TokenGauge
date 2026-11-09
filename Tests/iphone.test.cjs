// Checks the Scriptable widget's pure logic outside Scriptable (drawing is previewed separately).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../iPhone/Token Gauge.js'), 'utf8');
const marker = '// --- run (Scriptable) ---';
const plain = v => JSON.parse(JSON.stringify(v));
const ctx = vm.createContext({ Math, JSON, String, Number, Array, isFinite, Date, parseInt });
vm.runInContext(source.slice(0, source.indexOf(marker)) + '\n;Object.assign(globalThis, { resetText, validUsage, isStale, layout, cells, gaugeColors, LOGOS, offlineLabel, newer });', ctx);
test('script starts with Scriptable metadata and ends with the run block', () => {
  assert.ok(source.startsWith('// Variables used by Scriptable.'));
  assert.ok(source.includes(marker));
  assert.ok(!/new Request\(/.test(source), 'the widget must not make network requests');
});
test('reset text matches the Mac format', () => {
  const at = new Date(2026, 9, 29, 23, 59).getTime() / 1000;
  assert.equal(ctx.resetText(at, false), '11:59pm');
  assert.equal(ctx.resetText(at - 0.04, true), 'Thu 11:59pm');
  assert.equal(ctx.resetText(null, true), '—');
});
test('past resets and stale reports are never shown as current', () => {
  assert.equal(ctx.validUsage({ used: 70, reset: 1100 }, 1200), null);
  assert.equal(ctx.validUsage({ used: 0, reset: 1100 }, 1000), 0);
  assert.equal(ctx.isStale({ observedAt: 1000, stale: false }, 1000 + 900), true);
  assert.equal(ctx.isStale({ observedAt: 1000, stale: false }, 1000 + 899), false);
});
test('layouts put Grok on the left and Claude carries Fable', () => {
  const groups = ['claude', 'codex', 'grok'].map(id => ({ id, windows: id === 'grok' ? [{ label: '7D' }] : [{ label: '5H' }, { label: '7D' }, ...(id === 'claude' ? [{ label: 'FABLE' }] : [])] }));
  assert.deepEqual(plain(ctx.layout('medium', groups).map(c => c[0].group.id)), ['grok', 'claude', 'codex']);
  assert.deepEqual(plain(ctx.layout('small', groups).map(c => c.map(p => p.group.id))), [['grok'], ['claude', 'codex']]);
  assert.equal(ctx.layout('large', groups.slice(0, 2)).length, 1);
  assert.equal(ctx.cells(groups[0])[1].secondary.label, 'FABLE');
  assert.equal(ctx.cells(groups[2]).length, 1);
  assert.deepEqual(plain(ctx.gaugeColors('grok', true, true)), ['#BDBDBD', '#FFFFFF']);
  assert.deepEqual(plain(Object.keys(ctx.LOGOS)), ['claude', 'grok', 'codex']);
});

test('offline label gives the last report time; the newer copy wins', () => {
  const at = new Date(2026, 10, 10, 15, 12).getTime() / 1000;
  assert.equal(ctx.offlineLabel(at, at + 600), null);
  assert.equal(ctx.offlineLabel(at, at + 3600), 'Mac offline · 3:12pm');
  assert.equal(ctx.offlineLabel(at, at + 2 * 86400), 'Mac offline · Tue 3:12pm');
  const a = { generatedAt: 10, groups: [{}] }, b = { generatedAt: 20, groups: [{}] };
  assert.equal(ctx.newer(a, b), b);
  assert.equal(ctx.newer(b, a), b);
  assert.equal(ctx.newer(null, a), a);
  assert.equal(ctx.newer({ groups: [] }, null), null);
});
