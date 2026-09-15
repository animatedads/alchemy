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

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const child=spawn(path.join(root,'flylo'),['--port','0'],{
  cwd:root,
  env:{...process.env,FLYLO_ASSISTANT_REXX:path.join(root,'tests','fixtures','fake_rexx_internal.sh'),XAI_API_KEY:'FAKE',AI_GROK_MODELS:'grok-4.3',FLYLO_GROK_MODEL:'grok-4.3'},
  stdio:['ignore','pipe','pipe']
});
let stdout='',stderr=''; child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8'); child.stdout.on('data',c=>stdout+=c); child.stderr.on('data',c=>stderr+=c);
function readyUrl(){return new Promise((resolve,reject)=>{const t=setTimeout(()=>reject(new Error('not ready\n'+stdout+'\n'+stderr)),20000);const c=()=>{const m=stdout.match(/FLYLO_READY (http:\/\/[^\s]+)\//);if(m){clearTimeout(t);resolve(m[1]);}else setTimeout(c,25)};c();});}
async function ask(base,q,id){const r=await fetch(base+'/api/assistant',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({sessionId:id,question:q,history:[],context:{}})});const b=await r.json();assert.equal(r.status,200,JSON.stringify(b));assert.equal(b.ok,true);assert.equal(b.degraded,true);assert.doesNotMatch(b.text,/structured runtime failed safely|internal structured-runtime condition/i);return b;}
try{
 const base=await readyUrl();
 let b=await ask(base,'tell me about my booking','fallback-booking'); assert.match(b.text,/booking reference/i); assert.equal(b.frame.intent,'MANAGE_BOOKING');
 b=await ask(base,'I want to fly to new york','fallback-search'); assert.match(b.text,/New York/i); assert.equal(b.frame.intent,'BOOK_JOURNEY'); assert.equal(b.frame.slots.destination,'EWR');
 b=await ask(base,'can I book 10 tickets to new york','fallback-ten-tickets'); assert.match(b.text,/New York/i); assert.match(b.text,/10 passengers/i); assert.equal(b.frame.intent,'BOOK_JOURNEY'); assert.equal(b.frame.slots.destination,'EWR'); assert.equal(b.frame.slots.passengers,10); assert.deepEqual(b.missing,['origin','outboundDate','tripType']);
 await new Promise(r=>setTimeout(r,50));
 assert.match(stderr,/FLYLO_ASSISTANT_DIAGNOSTIC code=FLYLO_ASSISTANT_INTERNAL_INTERPRET_PROVIDER/);
 const health=await fetch(base+'/healthz').then(r=>r.json()); assert.equal(health.assistant.degraded,true); assert.equal(health.assistant.lastInternalCode,'FLYLO_ASSISTANT_INTERNAL_INTERPRET_PROVIDER');
 console.log('FLYLO INTERNAL FAILURE CONTINUITY: OK');
}finally{await stopChild(child);}
