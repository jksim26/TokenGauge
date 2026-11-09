// Save only quota percentages and reset times; forward the original input/output.
const { spawn } = require('node:child_process');
const { captureClaude, read } = require('./model.cjs');
let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', part => { raw += part; });
process.stdin.on('end', () => {
  try { captureClaude(JSON.parse(raw)); } catch { /* A cache failure must never break the status line. */ }
  const command = read('config.json')?.previousStatusLine?.command;
  if (!command) return;
  const child = spawn('/bin/sh', ['-c', command], { stdio: ['pipe', 'inherit', 'inherit'] });
  child.on('error', () => { process.exitCode = 1; });
  child.stdin.on('error', () => {});
  child.stdin.end(raw);
  child.on('exit', code => { process.exitCode = code || 0; });
});
