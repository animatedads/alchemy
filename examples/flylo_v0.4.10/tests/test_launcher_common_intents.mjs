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
    ...process.env, FLYLO_REXX: rexx,
    LD_LIBRARY_PATH: rexxLib + (process.env.LD_LIBRARY_PATH ? ':' + process.env.LD_LIBRARY_PATH : ''),
    FLYLO_TODAY: '2026-08-28', XAI_API_KEY: 'FAKE-FLYLO-XAI-SECRET',
    AI_GROK_ENDPOINT: 'http://fixture.invalid/v1/chat/completions', AI_GROK_ALLOW_HTTP_TEST: '1',
    AI_GROK_MODELS: 'fixture-model', FLYLO_GROK_MODEL: 'fixture-model', AI_GROK_MAX_OUTPUT: '900',
    FLYLO_GROK_MAX_OUTPUT: '900', AI_GROK_TIMEOUT: '5', FLYLO_GROK_REQUEST_TIMEOUT_MS: '30000',
    AI_GROK_CURL: path.join(root, 'tests', 'fixtures', 'fake_grok_chat_curl.sh')
  },
  stdio: ['ignore','pipe','pipe']
});
let stdout='', stderr='';
child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8');
child.stdout.on('data', c => stdout += c); child.stderr.on('data', c => stderr += c);
function readyUrl() { return new Promise((resolve,reject) => {
  const timer=setTimeout(() => reject(new Error('not ready\n'+stdout+'\n'+stderr)),20000);
  const check=()=>{ const m=stdout.match(/FLYLO_READY (http:\/\/[^\s]+)\//); if(m){clearTimeout(timer);resolve(m[1]);} else setTimeout(check,25); }; check();
}); }
async function ask(base, question, sessionId) {
  const r=await fetch(base+'/api/assistant',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({sessionId,question,history:[],context:{}})});
  const b=await r.json(); assert.equal(r.status,200,JSON.stringify(b)); assert.equal(b.ok,true,JSON.stringify(b)); assert.notEqual(b.degraded,true,JSON.stringify(b)); return b;
}
try {
  const base=await readyUrl();
  let b=await ask(base,'tell me about my booking','common-booking');
  assert.equal(b.frame.intent,'MANAGE_BOOKING');
  assert.equal(b.frame.serviceRequest,'BOOKING_LOOKUP');
  assert.deepEqual(b.missing,['bookingRef','familyName']);
  assert.match(b.text,/booking reference/i);
  assert.doesNotMatch(b.text,/structured runtime failed safely/i);
  b=await ask(base,'I want to fly to new york','common-search');
  assert.equal(b.frame.intent,'BOOK_JOURNEY');
  assert.equal(b.frame.slots.destination,'EWR');
  assert.deepEqual(b.missing,['origin','outboundDate','passengers','tripType']);
  assert.match(b.text,/New York/i);
  assert.doesNotMatch(b.text,/structured runtime failed safely/i);
  b=await ask(base,'can I book 10 tickets to new york','common-ten-tickets');
  assert.equal(b.frame.intent,'BOOK_JOURNEY');
  assert.equal(b.frame.slots.destination,'EWR');
  assert.equal(b.frame.slots.passengers,10);
  assert.deepEqual(b.missing,['origin','outboundDate','tripType']);
  assert.match(b.text,/10 seats/i);
  assert.match(b.text,/New York/i);
  assert.doesNotMatch(b.text,/language layer/i);
  assert.doesNotMatch(b.text,/structured runtime failed safely/i);
  console.log('FLYLO COMMON PASSENGER INTENTS: OK');
} finally { await stopChild(child); }
