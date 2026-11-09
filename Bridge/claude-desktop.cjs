const { execFile, spawn } = require('node:child_process');
const { promisify } = require('node:util');
const { pbkdf2Sync, createDecipheriv, createHash, timingSafeEqual } = require('node:crypto');
const path = require('node:path');
const os = require('node:os');
const fs = require('node:fs');
const exec = promisify(execFile);

function decryptCookie(row, password, version) {
  if (!['claude.ai', '.claude.ai'].includes(row.host_key)) throw new Error('Claude Desktop cookie host mismatch');
  if (row.value) return row.value;
  const encrypted = Buffer.from(row.encrypted, 'hex');
  if (encrypted.subarray(0, 3).toString() !== 'v10') throw new Error('Claude Desktop cookie encryption is unsupported');
  const key = pbkdf2Sync(password, 'saltysalt', 1003, 16, 'sha1');
  const decipher = createDecipheriv('aes-128-cbc', key, Buffer.alloc(16, 32));
  let clear;
  try { clear = Buffer.concat([decipher.update(encrypted.subarray(3)), decipher.final()]); }
  finally { key.fill(0); }
  if (version >= 24) {
    const expected = createHash('sha256').update(row.host_key).digest();
    if (clear.length < 32 || !timingSafeEqual(clear.subarray(0, 32), expected)) throw new Error('Claude Desktop cookie integrity check failed');
    clear = clear.subarray(32);
  }
  return clear.toString('utf8');
}
async function readSession() {
  const root = path.join(os.homedir(), 'Library/Application Support/Claude');
  const db = ['Cookies', 'Network/Cookies'].map(name => path.join(root, name)).find(file => fs.existsSync(file));
  if (!db) throw new Error('Open Claude Desktop and sign in to enable usage');
  let rows, version;
  try {
    const query = "SELECT host_key,name,value,hex(encrypted_value) AS encrypted,expires_utc FROM cookies WHERE host_key IN ('claude.ai','.claude.ai') AND name IN ('sessionKey','lastActiveOrg','cf_clearance','__cf_bm','anthropic-device-id') ORDER BY last_access_utc DESC;";
    const result = await exec('/usr/bin/sqlite3', ['-readonly', '-json', db, query], { timeout: 5000, maxBuffer: 65536 });
    rows = JSON.parse(result.stdout || '[]');
    const meta = await exec('/usr/bin/sqlite3', ['-readonly', db, "SELECT value FROM meta WHERE key='version';"], { timeout: 5000, maxBuffer: 1024 });
    version = Number(meta.stdout.trim());
  } catch { throw new Error('Claude Desktop session could not be read; open Claude Desktop'); }
  const now = (Date.now() + 11644473600000) * 1000;
  rows = rows.filter(row => !row.expires_utc || row.expires_utc > now);
  if (!rows.some(row => row.name === 'sessionKey')) throw new Error('Open Claude Desktop and sign in to renew its session');
  let password;
  try {
    const result = await exec('/usr/bin/security', ['find-generic-password', '-s', 'Claude Safe Storage', '-w'], { timeout: 15000, maxBuffer: 65536 });
    password = result.stdout.replace(/\r?\n$/, '');
  } catch { throw new Error('Claude Desktop Safe Storage is unavailable in Keychain'); }
  try {
    const cookies = {};
    for (const row of rows) { if (!(row.name in cookies)) cookies[row.name] = decryptCookie(row, password, version); }
    return { session: cookies.sessionKey, org: cookies.lastActiveOrg || null, cookies };
  } finally { password = null; }
}
async function queryDesktop() {
  let { session, org, cookies } = await readSession();
  const cookieHeader = Object.entries(cookies).filter(([name, value]) => /^[A-Za-z0-9_-]+$/.test(name) && /^[A-Za-z0-9._~%+\/=:-]+$/.test(value)).map(([name, value]) => `${name}=${value}`).join('; ');
  if (!/^sk-ant-[A-Za-z0-9_-]+$/.test(session)) throw new Error('Claude Desktop session format is unavailable');
  const get = async route => {
    const response = await new Promise((resolve, reject) => {
      const nativePath = path.join(__dirname, 'claude-web-request');
      const child = spawn(nativePath, [], { stdio: ['pipe', 'pipe', 'pipe'] });
      let output = '', count = 0;
      const timer = setTimeout(() => { child.kill(); reject(new Error('Claude Desktop usage request timed out')); }, 18000);
      child.stdout.on('data', chunk => { count += chunk.length; if (count > 2 * 1024 * 1024) child.kill(); else output += chunk; });
      child.stderr.on('data', () => {});
      child.on('error', () => { clearTimeout(timer); reject(new Error('Claude Desktop usage connection failed')); });
      child.on('close', code => {
        clearTimeout(timer);
        if (code !== 0) return reject(new Error('Claude Desktop usage connection failed'));
        try {
          const result = JSON.parse(output);
          resolve({ status: result.status, ok: result.status >= 200 && result.status < 300,
            challenge: /cf-chl|Just a moment|challenge-platform/i.test(result.body),
            headers: { get: () => result.retryAfter }, json: () => JSON.parse(result.body) });
        } catch { reject(new Error('Claude Desktop usage response was unreadable')); }

      });
      child.stdin.on('error', () => {});
      child.stdin.end(JSON.stringify({ path: route, cookie: cookieHeader }));
    });
    if (response.status === 429) {
      const error = new Error('Claude Desktop rate-limited usage checks; waiting before retrying');
      const retry = Number(response.headers.get('retry-after'));
      error.retryAfter = Math.max(180000, Number.isFinite(retry) && retry > 0 ? retry * 1000 : 600000);
      throw error;
    }
    if (response.status === 401) throw new Error('Open Claude Desktop and sign in to renew its session');
    if (response.status === 403) throw new Error(response.challenge ? 'Claude Desktop web requests are blocked by a security challenge; its in-app session may still work' : 'Claude Desktop web usage access was blocked (HTTP 403)');
    if (!response.ok) throw new Error(`Claude Desktop usage unavailable (HTTP ${response.status})`);
    return response.json();
  };
  try {
    if (org && /^[a-f0-9-]{36}$/i.test(org)) return await get(`/api/organizations/${org}/usage`);
    const organizations = await get('/api/organizations');
    if (!Array.isArray(organizations)) throw new Error('Claude Desktop organizations are unavailable');
    const selected = organizations.find(item => item.uuid === org) || (organizations.length === 1 ? organizations[0] : null);
    if (!selected || !/^[a-f0-9-]{36}$/i.test(selected.uuid)) throw new Error('Open Claude Desktop and select the account to track');
    return await get(`/api/organizations/${selected.uuid}/usage`);
  } finally { session = null; org = null; }
}
module.exports = { decryptCookie, queryDesktop };
