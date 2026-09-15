import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
async function stopChild(child, graceMs = 3000) {
  if (child.exitCode !== null) return child.exitCode;
  const exited = new Promise(resolve => child.once('exit', resolve));
  child.kill('SIGTERM');
  const outcome = await Promise.race([
    exited.then(code => ({ exited: true, code })),
    new Promise(resolve => setTimeout(() => resolve({ exited: false }), graceMs))
  ]);
  if (outcome.exited) return outcome.code;
  if (child.exitCode === null) child.kill('SIGKILL');
  return await exited;
}

const root = path.resolve(here, '..');
const launcher = path.join(root, 'flylo');

const child = spawn(launcher, ['--port', '0'], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
let stdout = '';
let stderr = '';
child.stdout.setEncoding('utf8');
child.stderr.setEncoding('utf8');
child.stdout.on('data', chunk => { stdout += chunk; });
child.stderr.on('data', chunk => { stderr += chunk; });

const timeout = setTimeout(() => {
  child.kill('SIGKILL');
  throw new Error(`launcher timeout; stdout=${stdout}; stderr=${stderr}`);
}, 20000);

try {
  const url = await new Promise((resolve, reject) => {
    const poll = setInterval(() => {
      const match = stdout.match(/FLYLO_READY\s+(http:\/\/\S+\/)/);
      if (match) {
        clearInterval(poll);
        resolve(match[1]);
      } else if (child.exitCode !== null) {
        clearInterval(poll);
        reject(new Error(`launcher exited ${child.exitCode}; stderr=${stderr}`));
      }
    }, 20);
  });

  const health = await fetch(new URL('healthz', url));
  assert.equal(health.status, 200);
  const healthJson = await health.json();
  assert.equal(healthJson.ok, true);
  assert.equal(healthJson.service, 'flylo-website');
  assert.equal(healthJson.assistant.transport, 'realtime');
  assert.equal(healthJson.assistant.batch, false);
  assert.equal(healthJson.assistant.configured, false);

  const unconfiguredChat = await fetch(new URL('api/assistant', url), {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ question: 'hello' })
  });
  assert.equal(unconfiguredChat.status, 503);
  const unconfiguredBody = await unconfiguredChat.json();
  assert.equal(unconfiguredBody.code, 'FLYLO_ASSISTANT_NOT_CONFIGURED');

  const page = await fetch(url);
  assert.equal(page.status, 200);
  const html = await page.text();
  assert.match(html, /<title>FlyLo/);
  assert.match(html, /id="search-form"/);
  assert.match(html, /id="assistant-panel"/);

  const js = await fetch(new URL('flylo.js', url));
  assert.equal(js.status, 200);
  assert.match(await js.text(), /FLIGHT\.SEARCH/);

  const traversal = await fetch(new URL('%2e%2e%2fVERSION.txt', url));
  assert.ok([400, 404].includes(traversal.status));

  const exitCode = await stopChild(child);
  assert.equal(exitCode, 0);
  console.log('PASS flylo single-command launcher');
} finally {
  clearTimeout(timeout);
  if (child.exitCode === null) child.kill('SIGKILL');
}
