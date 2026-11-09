const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'token-gauge-test-'));
process.env.TOKEN_GAUGE_DATA_DIR = dir;
const grokDir = path.join(dir, 'grok-bot');
process.env.TOKEN_GAUGE_GROK_DIR = grokDir;
const phoneDir = path.join(dir, 'scriptable');
process.env.TOKEN_GAUGE_SCRIPTABLE_DIR = phoneDir;
const model = require('../Bridge/model.cjs');
process.on('exit', () => fs.rmSync(dir, { recursive: true, force: true }));
test('missing reports are unavailable, never zero', () => {
  const snap = model.snapshot();
  assert.equal(snap.groups.length, 2);
  assert.equal(snap.groups[0].windows[0].used, null);
  assert.equal(snap.groups[0].stale, true);
});
test('Claude capture strips unrelated input and accepts zero usage', () => {
  model.captureClaude({ secret: 'DO_NOT_STORE', rate_limits: { five_hour: {used_percentage: 0, resets_at: 2000000000} } });
  const text = fs.readFileSync(path.join(dir, 'claude.json'), 'utf8');
  assert.ok(!text.includes('DO_NOT_STORE'));
  const data = JSON.parse(text);
  assert.equal(data.windows[0].used, 0);
  assert.equal(data.windows[1].used, null);
});
test('Codex durations determine labels and malformed numbers stay unknown', () => {
  assert.equal(model.window('5H', {usedPercent: 12, windowDurationMins: 60}, 18000).label, '1H');
  assert.equal(model.window('5H', {usedPercent: '12'}, 18000).used, null);
  assert.equal(model.window('5H', {usedPercent: Infinity}, 18000).used, null);
});
test('past reset hides old percentages without guessing zero', () => {
  model.write('codex.json', {observedAt: 1000, windows: [{label: '5H', used: 70, reset: 1100, duration:18000}]});
  assert.equal(model.snapshot(1200).groups[1].windows[0].used, null);
  assert.equal(model.snapshot(1001).groups[1].windows[0].used, 70);
  assert.equal(model.snapshot(2000).groups[1].stale, true);
});
test('status line passes stdin and stdout through byte for byte', () => {
  model.write('config.json', {previousStatusLine:{command: '/bin/cat'}});
  const input = JSON.stringify({model: {display_name:'Example'}, rate_limits:{five_hour:{used_percentage:24,resets_at:2000000000}}});
  const result = spawnSync(process.execPath, [path.join(__dirname, '../Bridge/claude-statusline.cjs')], {input, encoding:'utf8', env:process.env});
  assert.equal(result.status, 0);
  assert.equal(result.stdout, input);
  assert.equal(model.read('claude.json').windows[0].used, 24);
});

test('Fable comes from explicit scoped percentage, not weekly share', () => {
  const result = model.claudeWindows({
    five_hour: {utilization:6,resets_at:'2030-01-01T00:00:00Z'},
    seven_day: {utilization:96,resets_at:'2030-01-07T00:00:00Z'},
    weekly_scoped_shares:[{limit_index:2,used_percent_of_weekly:5}],
    limits:[
      {kind:'weekly_scoped',percent:10,resets_at:'2030-01-07T00:00:00Z',scope:{model:{display_name:'Fable'}}},
      {kind:'weekly_scoped',percent:'25',resets_at:'2030-01-07T00:00:00Z',scope:{model:{display_name:'Invalid'}}},
      {kind:'weekly_scoped',percent:96,resets_at:'2030-01-07T00:00:00Z',scope:{model:{display_name:'All models'}}}
    ]
  });
  assert.equal(result.length,3);
  assert.equal(result[2].label,'FABLE');
  assert.equal(result[2].used,10);
  assert.equal(result[2].duration,604800);
});

test('Grok appears only once Grok Bot is installed', () => {
  assert.equal(model.snapshot().groups.some(g => g.id === 'grok'), false);
  fs.mkdirSync(grokDir, { recursive: true });
  const grok = model.snapshot().groups.find(g => g.id === 'grok');
  assert.equal(grok.title, 'GROK');
  assert.deepEqual(grok.windows.map(w => [w.label, w.used, w.duration]), [['7D', null, 604800]]);
});
test('Grok weekly cache is decoded by file name and saves only usage fields', () => {
  const grok = require('../Bridge/grok.cjs');
  const name = key => { const a = 'abcdefghijklmnopqrstuvwxyz234567'; let bits = 0, v = 0, o = '';
    for (const b of Buffer.from(key)) { v = (v << 8) | b; bits += 8; while (bits >= 5) { o += a[(v >>> (bits - 5)) & 31]; bits -= 5; } }
    return (bits ? o + a[(v << (5 - bits)) & 31] : o) + '.blob'; };
  const cache = (pct, readAt) => JSON.stringify({ schemaVersion: 2, value: { kind: 'present', reading: { usage: { percentUsed: pct, nextResetMs: 2000000000000, grokPlanLabel: 'DO_NOT_STORE' }, readAtMs: readAt } } });
  fs.mkdirSync(grokDir, { recursive: true });
  fs.writeFileSync(path.join(grokDir, name('sand.client.slice.account.a.weekly-usage.cache')), cache(9.18, 1000000));
  fs.writeFileSync(path.join(grokDir, name('sand.client.slice.account.b.weekly-usage.cache')), cache(40, 2000000));
  fs.writeFileSync(path.join(grokDir, name('sand.client.slice.ui-layout')), cache(99, 3000000));
  assert.equal(grok.decodeName(name('sand.client.slice.ui-layout')), 'sand.client.slice.ui-layout');
  grok.pollGrok();
  const text = fs.readFileSync(path.join(dir, 'grok.json'), 'utf8');
  assert.ok(!text.includes('DO_NOT_STORE'));
  assert.deepEqual(JSON.parse(text), { observedAt: 2000, windows: [{ label: '7D', used: 40, reset: 2000000000, duration: 604800 }] });
  assert.equal(grok.parseCache('{"value":{"kind":"absent"}}'), null);
  assert.equal(grok.parseCache('not json'), null);
});

test('iPhone copy is published only when Scriptable syncs, and holds only the snapshot', () => {
  const value = model.snapshot();
  assert.equal(model.publishPhone(value), false);
  fs.mkdirSync(phoneDir, { recursive: true });
  assert.equal(model.publishPhone(value), true);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(phoneDir, 'Token Gauge.json'), 'utf8')), value);
  assert.deepEqual(fs.readdirSync(phoneDir), ['Token Gauge.json']);
});
