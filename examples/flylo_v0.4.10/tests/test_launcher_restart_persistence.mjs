import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const launcher=path.join(root,'flylo');
const dataDir=await fs.mkdtemp(path.join(os.tmpdir(),'flylo-v0410-restart-'));

async function start(){
  const child=spawn(launcher,['--port','0'],{cwd:root,env:{...process.env,FLYLO_DATA_DIR:dataDir},stdio:['ignore','pipe','pipe']});
  let stdout='',stderr=''; child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8'); child.stdout.on('data',c=>stdout+=c); child.stderr.on('data',c=>stderr+=c);
  const ready=await new Promise((resolve,reject)=>{const deadline=Date.now()+25000;const poll=()=>{const m=stdout.match(/FLYLO_READY\s+(http:\/\/\S+\/)/);if(m)return resolve(m[1]);if(child.exitCode!==null)return reject(new Error(`launcher exited ${child.exitCode}\n${stderr}`));if(Date.now()>deadline)return reject(new Error(`launcher timeout\n${stdout}\n${stderr}`));setTimeout(poll,25)};poll();});
  return {child,ready,get stderr(){return stderr;}};
}
async function stop(run){ if(run.child.exitCode===null) run.child.kill('SIGTERM'); await new Promise(resolve=>run.child.exitCode!==null?resolve():run.child.once('exit',resolve)); }
async function post(run,pathname,body,expected=200){const r=await fetch(new URL(pathname,run.ready),{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});const b=await r.json();assert.equal(r.status,expected,`${pathname}: ${JSON.stringify(b)}`);return b;}

let first,second;
try {
  first=await start();
  const health1=await (await fetch(new URL('healthz',first.ready))).json();
  assert.equal(health1.version,'0.4.10'); assert.equal(health1.runtime.storage,'DURABLE'); assert.equal(health1.runtime.accounting,'ACCOUNTING_CORE_0.7');
  const offer=(await post(first,'api/action',{action:'FLIGHT.SEARCH',detail:{origin:'PIK',destination:'EWR',date:'2026-09-12',passengers:2}})).result;
  const sale=(await post(first,'api/action',{action:'FLIGHT.SELECT',detail:{offerId:offer.offerId}})).result;
  assert.equal(sale.saleId,'SALE-00001');
  await post(first,'api/action',{action:'PASSENGER.SAVE',detail:{saleId:sale.saleId,passengers:[{givenName:'Tom',familyName:'Dyer'},{givenName:'Mia',familyName:'Dyer'}]}});
  await post(first,'api/action',{action:'ANCILLARY.SAVE',detail:{saleId:sale.saleId,selections:{CABIN_BAG:false,CHECKED_BAG:false,SEAT_SELECTION:false,PRIORITY_BOARDING:false}}});
  await post(first,'api/action',{action:'SALE.REVIEW',detail:{saleId:sale.saleId}});
  const confirmed=(await post(first,'api/action',{action:'PAYMENT.AUTHORIZE',detail:{saleId:sale.saleId,paymentMethodToken:'tok_restart_one'}})).result;
  const bookingRef=confirmed.booking.bookingRef;
  assert.deepEqual(confirmed.booking.passengers.map(p=>p.passengerId),['PAX-001','PAX-002']);
  const entryId=confirmed.accountingEntryId;
  await stop(first); first=null;

  second=await start();
  const health2=await (await fetch(new URL('healthz',second.ready))).json();
  assert.equal(health2.version,'0.4.10'); assert.equal(String(health2.runtime.wireUiServer),'0.17'); assert.equal(health2.runtime.engine,'QUEUE_FABRIC_DURABLE_FIXTURE');
  const reopened=(await post(second,'api/action',{action:'BOOKING.LOOKUP',detail:{bookingRef,familyName:'Dyer'}})).result;
  assert.deepEqual(reopened.passengers.map(p=>`${p.passengerId}:${p.givenName} ${p.familyName}`),['PAX-001:Tom Dyer','PAX-002:Mia Dyer']);
  assert.ok(reopened.workspaceContext.resultRevision>=1); assert.ok(reopened.workspaceContext.resultCurrent);
  assert.equal(reopened.status,'CONFIRMED');
  const offer2=(await post(second,'api/action',{action:'FLIGHT.SEARCH',detail:{origin:'PIK',destination:'EWR',date:'2026-09-12',passengers:1}})).result;
  const sale2=(await post(second,'api/action',{action:'FLIGHT.SELECT',detail:{offerId:offer2.offerId}})).result;
  assert.equal(sale2.saleId,'SALE-00002','restart must not reuse a durable sale/idempotency identity');
  const accountingText=await fs.readFile(path.join(dataDir,'accounting','flylo-stat.jsonl'),'utf8');
  assert.match(accountingText,/BOOK_CREATED/); assert.match(accountingText,/JOURNAL_POSTED/); assert.match(accountingText,new RegExp(entryId));
  console.log('FLYLO ./flylo DURABLE RESTART PASSENGER WORKSPACE: OK');
} finally {
  if(first) await stop(first);
  if(second) await stop(second);
  await fs.rm(dataDir,{recursive:true,force:true});
}
