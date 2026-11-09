// Grok weekly usage, read from Grok Bot's own local "weekly-usage.cache" display cache.
// That file holds only the usage reading Grok Bot last showed; Token Gauge never reads its tokens.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { write } = require('./model.cjs');

const PERSIST = process.env.TOKEN_GAUGE_GROK_DIR || path.join(os.homedir(), 'Library/Application Support/Grok Bot/sand-client-persistence');
const SUFFIX = '.weekly-usage.cache';

function decodeName(file) {
  // Grok Bot names each slice file with lowercase, unpadded base32 of its key.
  const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
  let bits = 0, value = 0, out = [];
  for (const char of file.replace(/\.blob$/, '')) {
    const index = alphabet.indexOf(char);
    if (index < 0) return null;
    value = (value << 5) | index; bits += 5;
    if (bits >= 8) { out.push((value >>> (bits - 8)) & 255); bits -= 8; }
  }
  return Buffer.from(out).toString('utf8');
}
function number(value) { return typeof value === 'number' && Number.isFinite(value) ? value : null; }
function parseCache(text) {
  let data; try { data = JSON.parse(text); } catch { return null; }
  const reading = data?.value?.kind === 'present' ? data.value.reading : null;
  const used = number(reading?.usage?.percentUsed), reset = number(reading?.usage?.nextResetMs), readAt = number(reading?.readAtMs);
  if (used === null || readAt === null) return null;
  return { observedAt: readAt / 1000,
    windows: [{ label: '7D', used: Math.min(100, Math.max(0, used)), reset: reset && reset > 0 ? reset / 1000 : null, duration: 604800 }] };
}
function grokInstalled() { return fs.existsSync(PERSIST); }
function pollGrok() {
  let message = null;
  try {
    if (!grokInstalled()) message = 'Install and open Grok Bot to track Grok usage';
    else {
      // Several signed-in accounts may each have a cache; use the most recent reading.
      const readings = fs.readdirSync(PERSIST).filter(file => decodeName(file)?.endsWith(SUFFIX))
        .map(file => parseCache(fs.readFileSync(path.join(PERSIST, file), 'utf8'))).filter(Boolean)
        .sort((a, b) => b.observedAt - a.observedAt);
      if (readings.length) write('grok.json', readings[0]);
      else message = 'Open Grok Bot to load its weekly usage';
    }
  } catch { message = 'Grok Bot usage could not be read; showing last report'; }
  write('grok-status.json', { message });
  return Promise.resolve();
}
module.exports = { decodeName, parseCache, grokInstalled, pollGrok, PERSIST };
