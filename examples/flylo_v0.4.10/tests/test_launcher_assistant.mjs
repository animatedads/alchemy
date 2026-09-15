import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

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

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const rexx = process.env.FLYLO_TEST_REXX;
const rexxLib = process.env.FLYLO_TEST_REXX_LIB;
assert.ok(rexx, 'FLYLO_TEST_REXX required');
assert.ok(rexxLib, 'FLYLO_TEST_REXX_LIB required');

const child = spawn(path.join(root, 'flylo'), ['--port', '0'], {
  cwd: root,
  env: {
    ...process.env,
    FLYLO_REXX: rexx,
    LD_LIBRARY_PATH: rexxLib + (process.env.LD_LIBRARY_PATH ? ':' + process.env.LD_LIBRARY_PATH : ''),
    XAI_API_KEY: 'FAKE-FLYLO-XAI-SECRET',
    AI_GROK_ENDPOINT: 'http://fixture.invalid/v1/chat/completions',
    AI_GROK_ALLOW_HTTP_TEST: '1',
    AI_GROK_MODELS: 'fixture-model',
    FLYLO_GROK_MODEL: 'fixture-model',
    AI_GROK_MAX_OUTPUT: '128',
    FLYLO_GROK_MAX_OUTPUT: '96',
    AI_GROK_TIMEOUT: '5',
    AI_GROK_CURL: path.join(root, 'tests', 'fixtures', 'fake_grok_chat_curl.sh')
  },
  stdio: ['ignore', 'pipe', 'pipe']
});

let stdout = '';
let stderr = '';
child.stdout.setEncoding('utf8');
child.stderr.setEncoding('utf8');
child.stdout.on('data', chunk => { stdout += chunk; });
child.stderr.on('data', chunk => { stderr += chunk; });

function readyUrl() {
  return new Promise((resolve, reject) => {
    const deadline = setTimeout(() => reject(new Error('FlyLo launcher did not become ready\n' + stdout + '\n' + stderr)), 20000);
    const check = () => {
      const match = stdout.match(/FLYLO_READY (http:\/\/[^\s]+)\//);
      if (match) { clearTimeout(deadline); resolve(match[1]); return; }
      setTimeout(check, 25);
    };
    check();
  });
}

try {
  const base = await readyUrl();
  const health = await fetch(base + '/healthz').then(r => r.json());
  assert.equal(health.ok, true);
  assert.equal(health.assistant.configured, true);
  assert.equal(health.assistant.transport, 'realtime');
  assert.equal(health.assistant.batch, false);

  const response = await fetch(base + '/api/assistant', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      question: 'Can I bring a cabin bag?',
      history: [{ role: 'user', content: 'I am looking at PIK to EWR.' }],
      context: {
        search: { origin: 'PIK', destination: 'EWR', date: '2026-09-12', passengers: 1 },
        sale: {
          state: 'EXTRAS', flightNo: 'FL101', origin: 'PIK', destination: 'EWR', date: '2026-09-12',
          totalMinor: 19900, currency: 'GBP', selectedExtras: [],
          passengerData: [{ email: 'secret@example.com' }], paymentMethodToken: 'tok_super_secret'
        }
      }
    })
  });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.match(body.text, /cabin-bag extra/i);
  assert.equal(body.model, 'fixture-model-actual');
  console.log('FLYLO LAUNCHER GROK REALTIME: OK');
} finally {
  await stopChild(child);
}
