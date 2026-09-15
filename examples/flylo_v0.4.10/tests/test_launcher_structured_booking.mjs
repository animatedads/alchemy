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
    FLYLO_TODAY: '2026-08-28',
    XAI_API_KEY: 'FAKE-FLYLO-XAI-SECRET',
    AI_GROK_ENDPOINT: 'http://fixture.invalid/v1/chat/completions',
    AI_GROK_ALLOW_HTTP_TEST: '1',
    AI_GROK_MODELS: 'fixture-model',
    FLYLO_GROK_MODEL: 'fixture-model',
    AI_GROK_MAX_OUTPUT: '700',
    FLYLO_GROK_MAX_OUTPUT: '700',
    AI_GROK_TIMEOUT: '5',
    FLYLO_GROK_REQUEST_TIMEOUT_MS: '20000',
    AI_GROK_CURL: path.join(root, 'tests', 'fixtures', 'fake_grok_chat_curl.sh')
  },
  stdio: ['ignore', 'pipe', 'pipe']
});

let stdout = '';
let stderr = '';
child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8');
child.stdout.on('data', c => { stdout += c; }); child.stderr.on('data', c => { stderr += c; });
function readyUrl() {
  return new Promise((resolve, reject) => {
    const deadline = setTimeout(() => reject(new Error('FlyLo launcher did not become ready\n' + stdout + '\n' + stderr)), 20000);
    const check = () => {
      const m = stdout.match(/FLYLO_READY (http:\/\/[^\s]+)\//);
      if (m) { clearTimeout(deadline); resolve(m[1]); return; }
      setTimeout(check, 25);
    };
    check();
  });
}

const sessionId = 'structured-booking-fixture';
let history = [];
async function ask(base, question) {
  const prior = history.slice(-8);
  const response = await fetch(base + '/api/assistant', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ sessionId, question, history: prior, context: {} })
  });
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true);
  history.push({ role: 'user', content: question }, { role: 'assistant', content: body.text });
  return body;
}

try {
  const base = await readyUrl();
  const health = await fetch(base + '/healthz').then(r => r.json());
  assert.equal(health.assistant.structuredLanguage, true);
  assert.equal(health.assistant.structuredUtterance, 'structured.utterance/0.3');
  assert.equal(health.assistant.batch, false);

  let body = await ask(base, 'I want to book a flight');
  assert.equal(body.frame.intent, 'BOOK_JOURNEY');
  assert.equal(body.action, null);

  body = await ask(base, 'Glasgow to New York');
  assert.equal(body.frame.slots.origin, 'GLA');
  assert.equal(body.frame.slots.destination, 'EWR');

  body = await ask(base, '29th and 2');
  assert.equal(body.frame.slots.outboundDay, 29);
  assert.equal(body.frame.slots.passengers, 2);

  body = await ask(base, 'next month');
  assert.equal(body.frame.slots.outboundDate, '2026-09-29');
  assert.ok(body.missing.includes('tripType'));

  body = await ask(base, 'one way please');
  assert.equal(body.frame.slots.tripType, 'ONE_WAY');
  assert.deepEqual(body.missing, []);
  assert.equal(body.action.type, 'FLIGHT_SEARCH_RESULT');
  const offer = body.action.offer;
  assert.equal(offer.source, 'ENGINE_FIXTURE');
  assert.equal(offer.origin, 'GLA');
  assert.equal(offer.destination, 'EWR');
  assert.equal(offer.date, '2026-09-29');
  assert.equal(offer.passengers, 2);
  assert.equal(offer.fareMinor, 23800);
  assert.equal(offer.totalFareMinor, 47600);
  assert.equal(offer.legs.length, 2);
  assert.equal(offer.legs[0].flightNo, 'FL201');
  assert.equal(offer.legs[1].flightNo, 'FL101');
  assert.match(body.text, /GBP 476\.00/i);
  assert.equal(body.structuredUtterance.schema, 'structured.utterance/0.3');
  assert.equal(body.structuredUtterance.sealed, true);
  assert.equal(body.structuredUtterance.communicativeAct, 'SERVICE_RESOLUTION');
  assert.equal(body.structuredUtterance.intendedAct, 'PRESENT_FLIGHT_OPTIONS');
  assert.equal(body.structuredUtterance.lineageCount, 2);
  assert.match(body.structuredUtterance.canonicalText, /FLYLO_JOURNEY_ENGINE_SEARCH/);
  console.log('FLYLO STRUCTURED BOOKING CONVERSATION: OK');
} finally {
  await stopChild(child);
}
