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
    AI_GROK_MAX_OUTPUT: '900',
    FLYLO_GROK_MAX_OUTPUT: '900',
    AI_GROK_TIMEOUT: '5',
    FLYLO_GROK_REQUEST_TIMEOUT_MS: '30000',
    AI_GROK_CURL: path.join(root, 'tests', 'fixtures', 'fake_grok_chat_curl.sh')
  },
  stdio: ['ignore', 'pipe', 'pipe']
});
let stdout = '', stderr = '';
child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8');
child.stdout.on('data', c => stdout += c); child.stderr.on('data', c => stderr += c);
function readyUrl() {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('not ready\n' + stdout + '\n' + stderr)), 20000);
    const check = () => {
      const m = stdout.match(/FLYLO_READY (http:\/\/[^\s]+)\//);
      if (m) { clearTimeout(timer); resolve(m[1]); } else setTimeout(check, 25);
    };
    check();
  });
}
const sessionId = 'postbooking-transcript';
const history = [];
async function ask(base, question) {
  const r = await fetch(base + '/api/assistant', {
    method: 'POST', headers: {'content-type':'application/json'},
    body: JSON.stringify({ sessionId, question, history: history.slice(-8), context: {} })
  });
  const body = await r.json();
  assert.equal(r.status, 200, JSON.stringify(body));
  assert.equal(body.ok, true, JSON.stringify(body));
  history.push({role:'user',content:question},{role:'assistant',content:body.text});
  return body;
}
try {
  const base = await readyUrl();
  const health = await fetch(base + '/healthz').then(r => r.json());
  assert.equal(health.assistant.structuredOutput, 'xai-json-schema-strict');
  assert.equal(health.assistant.structuredFrame, 'flylo.assistant.frame/0.2');
  assert.equal(health.assistant.batch, false);

  let b = await ask(base, 'hi, I booked a flight and I need help with it');
  assert.equal(b.frame.intent, 'MANAGE_BOOKING');
  assert.equal(b.frame.serviceRequest, 'BOOKING_LOOKUP');
  assert.deepEqual(b.missing, ['bookingRef','familyName']);
  assert.equal(b.action.type, 'BOOKING_SERVICE_REQUIRED');
  assert.match(b.text, /booking reference/i);

  b = await ask(base, 'I need an extra bag on my flight Tom Dyer, Glasgow to Newark on 29-08');
  assert.equal(b.frame.serviceRequest, 'ADD_CHECKED_BAG');
  assert.equal(b.frame.slots.familyName, 'Dyer');
  assert.equal(b.frame.slots.origin, 'GLA');
  assert.equal(b.frame.slots.destination, 'EWR');
  assert.equal(b.frame.slots.outboundDate, '2026-08-29');
  assert.deepEqual(b.missing, ['bookingRef']);
  assert.doesNotMatch(b.text, /number of passengers|one-way or return|return trip/i);
  assert.match(b.text, /booking reference/i);

  b = await ask(base, 'me and my daughter, one way.  Will I have a problem at migration?  I am columbian');
  assert.equal(b.frame.serviceRequest, 'ADD_CHECKED_BAG');
  assert.equal(b.frame.informationRequest, 'IMMIGRATION_ENTRY');
  assert.equal(b.frame.slots.documentCountry, 'COL');
  assert.equal(b.frame.slots.passengers, 2);
  assert.equal(b.frame.slots.tripType, 'ONE_WAY');
  assert.deepEqual(b.missing, ['bookingRef']);
  assert.match(b.text, /Colombian passport/i);
  assert.match(b.text, /Visa Waiver Program/i);
  assert.match(b.text, /booking reference/i);
  assert.doesNotMatch(b.text, /number of passengers/i);

  b = await ask(base, 'my daugher wants the extra bags for our duty free cigarettes over her allowance,  This can be checked bags right?');
  assert.equal(b.frame.serviceRequest, 'ADD_CHECKED_BAG');
  assert.equal(b.frame.informationRequest, 'CUSTOMS_TOBACCO');
  assert.equal(b.frame.slots.companionChildMentioned, true);
  assert.equal(b.frame.slots.tobaccoForCompanion, true);
  assert.equal(b.authorityEvidence.customsTobacco.adultMinimumAge, 21);
  assert.equal(b.authorityEvidence.customsTobacco.publishedCigaretteQuantity, 200);
  assert.equal(b.authorityEvidence.customsTobacco.ageClarificationNeeded, true);
  assert.equal(b.authorityEvidence.cigaretteBaggage.ordinaryCigarettesCheckedBaggagePermitted, true);
  assert.match(b.text, /checked baggage/i);
  assert.match(b.text, /duty-free/i);
  assert.match(b.text, /21\+/i);
  assert.match(b.text, /200 cigarettes/i);
  assert.match(b.text, /How old is she/i);
  assert.match(b.text, /booking reference/i);
  assert.equal(b.structuredUtterance.schema, 'structured.utterance/0.3');
  assert.equal(b.structuredUtterance.sealed, true);
  assert.match(b.structuredUtterance.canonicalText, /US_CBP_TOBACCO_AND_TSA_BAGGAGE_SNAPSHOT/);
  console.log('FLYLO POST-BOOKING ASSISTANT TRANSCRIPT: OK');
} finally {
  await stopChild(child);
}
