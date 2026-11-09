const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const DATA = process.env.TOKEN_GAUGE_DATA_DIR || path.join(os.homedir(), 'Library', 'Application Support', 'Token Gauge');
function read(name) { try { return JSON.parse(fs.readFileSync(path.join(DATA, name), 'utf8')); } catch { return null; } }
function write(name, value) {
  fs.mkdirSync(DATA, { recursive: true, mode: 0o700 });
  const dest = path.join(DATA, name), tmp = `${dest}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(value), { mode: 0o600 });
  fs.renameSync(tmp, dest);
}
function number(value) { return typeof value === 'number' && Number.isFinite(value) ? value : null; }
function window(label, value, duration) {
  if (!value) return { label, used: null, reset: null, duration };
  const pct = number(value.usedPercent ?? value.used_percentage);
  const reset = number(value.resetsAt ?? value.resets_at);
  const mins = number(value.windowDurationMins);
  const seconds = mins && mins > 0 ? mins * 60 : duration;
  const title = seconds === 18000 ? '5H' : seconds === 604800 ? '7D' : seconds % 3600 === 0 ? `${seconds / 3600}H` : `${Math.round(seconds / 60)}M`;
  return { label: title, used: pct === null ? null : Math.min(100, Math.max(0, pct)), reset, duration: seconds };
}
function snapshot(now = Date.now() / 1000) {
  // Grok appears only once Grok Bot is installed or has reported.
  const ids = ['claude', 'codex'];
  const grokDir = process.env.TOKEN_GAUGE_GROK_DIR || path.join(os.homedir(), 'Library/Application Support/Grok Bot/sand-client-persistence');
  if (fs.existsSync(grokDir) || read('grok.json')) ids.push('grok');
  const titles = { claude: 'CLAUDE', codex: 'CODEX', grok: 'GROK' };
  const waiting = { claude: 'Waiting for Claude Code', codex: 'Waiting for Codex', grok: 'Waiting for Grok Bot' };
  const groups = ids.map(id => {
    const cached = read(`${id}.json`);
    const windows = cached?.windows || (id === 'grok' ? [{ label: '7D', used: null, reset: null, duration: 604800 }] : [window('5H', null, 18000), window('7D', null, 604800)]);
    return { id, title: titles[id], observedAt: cached?.observedAt ?? null,
      stale: !cached?.observedAt || now - cached.observedAt > 900,
      message: read(`${id}-status.json`)?.message || (cached ? null : waiting[id]),
      windows: windows.map(w => ({ ...w, used: w.reset && w.reset <= now ? null : w.used })) };
  });
  return { version: 1, generatedAt: now, groups };
}
function captureClaude(input) {
  if (!input?.rate_limits || typeof input.rate_limits !== 'object') return false;
  const limits = input.rate_limits;
  write('claude.json', { observedAt: Date.now() / 1000, windows: [window('5H', limits.five_hour, 18000), window('7D', limits.seven_day, 604800)] });
  return true;
}
function claudeWindows(value) {
  const normalize = raw => raw && typeof raw === 'object' ? {
    used_percentage: raw.utilization,
    resets_at: typeof raw.resets_at === 'string' ? Date.parse(raw.resets_at) / 1000 : raw.resets_at
  } : null;
  const result = [window('5H', normalize(value.five_hour), 18000), window('7D', normalize(value.seven_day), 604800)];
  const seen = new Set();
  for (const item of Array.isArray(value.limits) ? value.limits : []) {
    const name = item?.scope?.model?.display_name;
    if (item?.kind !== 'weekly_scoped' || typeof name !== 'string' || !name.trim() || /all models/i.test(name) || number(item.percent) === null) continue;
    const label = name.trim().slice(0, 10).toUpperCase();
    if (seen.has(label)) continue;
    const reset = typeof item.resets_at === 'string' ? Date.parse(item.resets_at) / 1000 : item.resets_at;
    if (number(reset) === null) continue;
    seen.add(label);
    result.push({ ...window(label, { used_percentage: item.percent, resets_at: reset }, 604800), label, scoped: true });
  }
  return result;
}
// iPhone: mirror the sanitized snapshot into Scriptable's iCloud Drive folder, only if Scriptable syncs there.
const SCRIPTABLE = process.env.TOKEN_GAUGE_SCRIPTABLE_DIR || path.join(os.homedir(), 'Library/Mobile Documents/iCloud~dk~simonbs~Scriptable/Documents');
function publishPhone(value) {
  try {
    if (!fs.existsSync(SCRIPTABLE)) return false;
    const dest = path.join(SCRIPTABLE, 'Token Gauge.json'), tmp = path.join(SCRIPTABLE, `.token-gauge.${process.pid}.tmp`);
    fs.writeFileSync(tmp, JSON.stringify(value), { mode: 0o600 });
    fs.renameSync(tmp, dest);
    return true;
  } catch { return false; }
}
module.exports = { DATA, SCRIPTABLE, read, write, window, snapshot, captureClaude, claudeWindows, publishPhone };
