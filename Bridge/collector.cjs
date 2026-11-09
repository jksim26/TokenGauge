const http = require('node:http');
const { spawn } = require('node:child_process');
const readline = require('node:readline');
const { read, write, window, snapshot, publishPhone } = require('./model.cjs');
const { pollClaude } = require('./claude-fetch.cjs');
const { pollGrok } = require('./grok.cjs');
let current = null, lastAttempt = 0, child = null;
function poll(force = false) {
  if (current) return current;
  if (!force && Date.now() - lastAttempt < 60000) return Promise.resolve();
  lastAttempt = Date.now();
  current = new Promise(resolve => {
    let finished = false;
    const finish = (message) => {
      if (finished) return;
      finished = true; clearTimeout(timeout);
      write('codex-status.json', { message });
      child?.kill(); child = null;
      resolve();
    };
    const timeout = setTimeout(() => finish('Codex did not respond; showing last report'), 25000);
    const config = read('config.json');
    if (!config?.codexPath) return finish('Install and sign in to Codex');
    child = spawn(config.codexPath, ['app-server', '--listen', 'stdio://'], { stdio: ['pipe', 'pipe', 'ignore'], env: { ...process.env, PATH: config.path || process.env.PATH } });
    child.on('error', () => finish('Cannot start Codex; check installation'));
    child.on('exit', () => finish('Codex stopped; showing last report'));
    child.stdin.on('error', () => {});
    const send = value => { if (child?.stdin.writable) child.stdin.write(JSON.stringify(value) + '\n'); };
    const lines = readline.createInterface({ input: child.stdout });
    lines.on('line', line => {
      let message; try { message = JSON.parse(line); } catch { return; }
      if (message.id === 1) {
        if (message.error) return finish('Codex initialization failed');
        send({ method: 'initialized' });
        send({ id: 2, method: 'account/rateLimits/read' });
      } else if (message.id === 2) {
        if (message.error) return finish('Codex usage unavailable; check Codex sign-in');
        const result = message.result || {};
        const bucket = result.rateLimitsByLimitId?.codex || result.rateLimits;
        if (!bucket) return finish('Codex returned no usage windows');
        write('codex.json', { observedAt: Date.now() / 1000, windows: [window('5H', bucket.primary, 18000), window('7D', bucket.secondary, 604800)] });
        finish(null);
      }
    });
    send({ id: 1, method: 'initialize', params: { clientInfo: { name: 'token_gauge', title: 'Token Gauge', version: '1.0.0' } } });
  }).finally(() => { current = null; write('snapshot.json', snapshot()); });
  return current;
}
const server = http.createServer(async (req, res) => {
  // Loopback only. No CORS: browser pages cannot read local usage reports.
  if (req.headers.origin || !['127.0.0.1:43871', 'localhost:43871'].includes(req.headers.host)) { res.writeHead(403); return res.end(); }
  if (req.method === 'POST' && req.url === '/refresh') { await Promise.allSettled([poll(), pollClaude(), pollGrok()]); publishPhone(snapshot()); }
  else if (req.method !== 'GET' || req.url !== '/snapshot') { res.writeHead(404); return res.end(); }
  const value = snapshot(); write('snapshot.json', value);
  res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(value));
});
server.on('error', err => { console.error(`Token Gauge could not start: ${err.code}`); process.exit(1); });
// The iPhone copy is published once per polling cycle, not on every widget read, to limit iCloud uploads.
function refreshAll() { return Promise.allSettled([poll(true), pollClaude(), pollGrok()]).then(() => { const value = snapshot(); write('snapshot.json', value); publishPhone(value); }); }
server.listen(43871, '127.0.0.1', refreshAll);
setInterval(refreshAll, 180000).unref();
function stop() { child?.kill(); server.close(); process.exit(0); }
process.on('SIGTERM', stop); process.on('SIGINT', stop);
