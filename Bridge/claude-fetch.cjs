const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const { write, claudeWindows } = require('./model.cjs');
const exec = promisify(execFile);
const { queryDesktop } = require('./claude-desktop.cjs');
let current = null, nextAttempt = 0;

// Read Claude Code's existing credential in memory. Never persist tokens or
// attempt to rotate credentials that belong to Claude Code.
async function queryCode() {
  let text;
  try {
    ({ stdout: text } = await exec('/usr/bin/security', ['find-generic-password', '-s', 'Claude Code-credentials', '-w'], { timeout: 8000, maxBuffer: 1024 * 1024 }));
  } catch { throw new Error('Claude sign-in unavailable in Keychain; open Claude Code'); }
  let credential;
  try { credential = JSON.parse(text)?.claudeAiOauth; }
  catch { throw new Error('Claude sign-in format is unavailable'); }
  text = null;
  if (!credential?.accessToken) throw new Error('Sign in to Claude Code to enable automatic usage');
  if (credential.expiresAt && credential.expiresAt <= Date.now()) throw new Error('Open Claude Code to renew its sign-in');
  const response = await fetch('https://api.anthropic.com/api/oauth/usage', {
    headers: { Authorization: `Bearer ${credential.accessToken}`, 'anthropic-beta': 'oauth-2025-04-20', 'User-Agent': 'TokenGauge/1.0' },
    redirect: 'error', signal: AbortSignal.timeout(15000)
  });
  credential = null;
  if (response.status === 429) {
    const delay = Number(response.headers.get('retry-after'));
    nextAttempt = Date.now() + Math.max(180000, Number.isFinite(delay) ? delay * 1000 : 600000);
    throw new Error('Claude rate-limited usage checks; waiting before retrying');
  }
  if (response.status === 401 || response.status === 403) throw new Error('Claude usage access rejected; check Claude Code sign-in');
  if (!response.ok) throw new Error(`Claude usage unavailable (HTTP ${response.status})`);
  const value = await response.json();
  const windows = claudeWindows(value);
  if (windows.every(w => w.used === null)) throw new Error('Claude returned no subscription usage windows');
  return { windows, source: 'claude-code' };
}
async function query() {
  let desktopError;
  try {
    const value = await queryDesktop();
    const windows = claudeWindows(value);
    if (windows.every(w => w.used === null)) throw new Error('Claude Desktop returned no subscription usage windows');
    write('claude.json', { observedAt: Date.now() / 1000, windows, source: 'claude-desktop' });
    return;
  } catch (error) {
    desktopError = error;
    if (error.retryAfter) nextAttempt = Date.now() + error.retryAfter;
  }
  try {
    const result = await queryCode();
    write('claude.json', { observedAt: Date.now() / 1000, ...result });
  } catch {
    throw new Error(desktopError.message.startsWith('Claude') || desktopError.message.startsWith('Open') ? desktopError.message : 'Claude Desktop usage could not refresh; showing last report');
  }
}
function pollClaude() {
  if (current) return current;
  if (Date.now() < nextAttempt) return Promise.resolve();
  nextAttempt = Date.now() + 60000;
  current = query()
    .then(() => write('claude-status.json', { message: null }))
    .catch(error => write('claude-status.json', { message: error.message.startsWith('Claude') || error.message.startsWith('Open') || error.message.startsWith('Sign') ? error.message : 'Claude usage could not refresh; showing last report' }))
    .finally(() => { current = null; });
  return current;
}
module.exports = { pollClaude };
if (require.main === module) pollClaude().then(() => {
  const { read } = require('./model.cjs');
  console.log(JSON.stringify({ status: read('claude-status.json'), usage: read('claude.json') }));
});
