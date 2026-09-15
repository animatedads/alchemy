import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs/promises';
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
const launcher=path.join(root,'flylo');
const dataDir=await fs.mkdtemp(path.join(os.tmpdir(),'flylo-v0410-manage-'));
const child=spawn(launcher,['--port','0'],{cwd:root,env:{...process.env,FLYLO_DATA_DIR:dataDir},stdio:['ignore','pipe','pipe']});
let stdout='',stderr=''; child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8'); child.stdout.on('data',c=>stdout+=c); child.stderr.on('data',c=>stderr+=c);
const ready=await new Promise((resolve,reject)=>{const deadline=Date.now()+15000;const poll=()=>{const m=stdout.match(/FLYLO_READY\s+(http:\/\/\S+\/)/);if(m)return resolve(m[1]);if(child.exitCode!==null)return reject(new Error(`launcher exited ${child.exitCode}\n${stderr}`));if(Date.now()>deadline)return reject(new Error(`launcher timeout\n${stdout}\n${stderr}`));setTimeout(poll,25)};poll();});
async function post(pathname,body,expected=200){const r=await fetch(new URL(pathname,ready),{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});const b=await r.json();assert.equal(r.status,expected,`${pathname}: ${JSON.stringify(b)}`);return b;}
try {
  const health=await (await fetch(new URL('healthz',ready))).json();
  assert.equal(health.version,'0.4.10'); assert.equal(health.runtime.ready,true); assert.equal(String(health.runtime.wireUiServer),'0.17'); assert.equal(health.runtime.engine,'QUEUE_FABRIC_DURABLE_FIXTURE'); assert.equal(health.runtime.accounting,'ACCOUNTING_CORE_0.7'); assert.equal(health.runtime.storage,'DURABLE');
  const html=await (await fetch(ready)).text(); assert.match(html,/data-demo-mode="false"/); assert.match(html,/id="manage-process"/); assert.match(html,/id="runtime-build"/); assert.match(html,/Wire UI Server v0\.17/); assert.match(html,/content="\/api\/action"/);
  const browserJs=await (await fetch(new URL('flylo.js',ready))).text();
  assert.match(browserJs,/openManage\(sale\.booking\.bookingRef, surname, true\)/,'confirmed booking should open its workspace directly');
  assert.doesNotMatch(browserJs,/RUNTIME_CONDITION_88\.900/,'browser must not encode internal ooRexx condition text');
  const screenshotLookup=await post('api/action',{action:'BOOKING.LOOKUP',detail:{bookingRef:'12',familyName:'dyer'}},404);
  assert.equal(screenshotLookup.code,'BOOKING_LOOKUP_NOT_MATCHED');
  assert.doesNotMatch(JSON.stringify(screenshotLookup),/RUNTIME_CONDITION|position=27/);

  const search=(await post('api/action',{action:'FLIGHT.SEARCH',detail:{origin:'PIK',destination:'EWR',date:'2026-09-12',passengers:2}})).result;
  const sale=(await post('api/action',{action:'FLIGHT.SELECT',detail:{offerId:search.offerId}})).result;
  assert.match(sale.saleId,/^SALE-\d{5}$/);
  await post('api/action',{action:'PASSENGER.SAVE',detail:{saleId:sale.saleId,passengers:[{givenName:'Tom',familyName:'Dyer',email:'tom@example.invalid'},{givenName:'Mia',familyName:'Dyer'}]}});
  await post('api/action',{action:'ANCILLARY.SAVE',detail:{saleId:sale.saleId,selections:{CABIN_BAG:false,CHECKED_BAG:false,SEAT_SELECTION:false,PRIORITY_BOARDING:false}}});
  await post('api/action',{action:'SALE.REVIEW',detail:{saleId:sale.saleId}});
  const confirmed=(await post('api/action',{action:'PAYMENT.AUTHORIZE',detail:{saleId:sale.saleId,paymentMethodToken:'tok_demo_browser'}})).result;
  assert.equal(confirmed.paymentCaptureStatus,'CAPTURED'); assert.equal(confirmed.accountingStatus,'POSTED'); assert.match(confirmed.accountingEntryId,/^FLYLO-STAT-J\d{10}$/);
  const bookingRef=confirmed.booking.bookingRef; assert.ok(bookingRef); assert.equal(confirmed.booking.passengers[1].passengerId,'PAX-002'); assert.equal(confirmed.booking.passengers?.[0]?.familyName,'Dyer');

  const wrongSurname=await post('api/action',{action:'BOOKING.LOOKUP',detail:{bookingRef,familyName:'NotDyer'}},404);
  assert.equal(wrongSurname.code,'BOOKING_LOOKUP_NOT_MATCHED');

  const workspace=(await post('api/action',{action:'BOOKING.LOOKUP',detail:{bookingRef,familyName:'Dyer'}})).result;
  assert.match(workspace.workspaceContext.workspaceRef,new RegExp(`^BOOKING\\.${bookingRef}\\.PASSENGERS$`));
  assert.deepEqual(workspace.workspaceContext.selectedIds,[]); assert.ok(workspace.workspaceContext.resultRevision>=1); assert.ok(workspace.workspaceContext.resultCurrent);
  assert.deepEqual(workspace.passengers.map(p=>`${p.givenName} ${p.familyName}`),['Tom Dyer','Mia Dyer']);
  const selected=(await post('api/workspace/select',{workspaceRef:workspace.workspaceContext.workspaceRef,scopeRevision:workspace.workspaceContext.scopeRevision,selectedIds:['PAX-002']})).result;
  const stale=structuredClone(selected);
  const sorted=(await post('api/workspace/sort',{workspaceRef:workspace.workspaceContext.workspaceRef,sortRef:'familyName',direction:'DESC'})).result;
  assert.deepEqual(sorted.selectedIds,['PAX-002']); assert.ok(sorted.queryRevision>stale.queryRevision); assert.ok(sorted.resultRevision>stale.resultRevision); assert.ok(sorted.resultCurrent);
  const staleReply=await post('api/action',{action:'BOOKING.ADD_CHECKED_BAG',detail:{workspaceContext:stale,quantity:1,paymentMethodToken:'tok_demo_servicing'}},409);
  assert.equal(staleReply.code,'WORKSPACE_QUERY_REVISION_MISMATCH');
  const forged={...sorted,selectedIds:['PAX-999']};
  const forgedReply=await post('api/action',{action:'BOOKING.ADD_CHECKED_BAG',detail:{workspaceContext:forged,quantity:1,paymentMethodToken:'tok_demo_servicing'}},409);
  assert.equal(forgedReply.code,'WORKSPACE_SELECTION_MISMATCH');
  const managed=(await post('api/action',{action:'BOOKING.ADD_CHECKED_BAG',detail:{workspaceContext:sorted,quantity:1,paymentMethodToken:'tok_demo_servicing'}})).result;
  assert.equal(managed.passengers.find(p=>p.passengerId==='PAX-001').checkedBagCount,0);
  assert.equal(managed.passengers.find(p=>p.passengerId==='PAX-002').checkedBagCount,1);
  assert.equal(managed.lastAncillaryService.amountMinor,4900); assert.deepEqual(managed.lastAncillaryService.passengerIds,['PAX-002']);
  assert.equal(managed.lastAncillaryFinancialStatus,'CAPTURED'); assert.equal(managed.lastAncillaryAccountingStatus,'POSTED'); assert.match(managed.lastAncillaryAccountingEntryId,/^FLYLO-STAT-J\d{10}$/);
  assert.ok(managed.workspaceContext.resultRevision>sorted.resultRevision); assert.ok(managed.workspaceContext.resultCurrent);
  const staleResultReply=await post('api/action',{action:'BOOKING.ADD_CHECKED_BAG',detail:{workspaceContext:sorted,quantity:1,paymentMethodToken:'tok_demo_servicing'}},409);
  assert.equal(staleResultReply.code,'WORKSPACE_RESULT_REVISION_MISMATCH');
  const refreshed=(await post('api/action',{action:'BOOKING.LOOKUP',detail:{bookingRef,familyName:'Dyer'}})).result;
  assert.equal(refreshed.passengers.find(p=>p.passengerId==='PAX-002').checkedBagCount,1);
  console.log('FLYLO ./flylo SERVER-BACKED MANAGE WORKSPACE: OK');
} finally {
  await stopChild(child);
  await fs.rm(dataDir,{recursive:true,force:true});
}
