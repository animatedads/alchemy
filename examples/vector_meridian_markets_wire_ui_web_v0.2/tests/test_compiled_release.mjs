import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const pkg=JSON.parse(fs.readFileSync(path.join(root,'compiled/vector_meridian_markets_operations_v0.2.json'),'utf8'));
const defs=new Map(pkg.definitions.map(d=>[d.definitionKey,d]));

test('compiled release is exact VMM operator release',()=>{
  assert.equal(pkg.packageId,'VECTOR_MERIDIAN_MARKETS_OPERATIONS');
  assert.equal(String(pkg.packageVersion),'2');
  assert.match(pkg.contentAddress,/^wuid01-/);
  assert.equal(pkg.definitions.length,23);
  assert.equal(pkg.journeyPlans.length,1);
});

test('server-authoritative operator intents are compiled, not browser literals',()=>{
  const expected={
    'VMM_ORDER_CANCEL@2':'VMM.ORDER.CANCEL.REQUEST',
    'VMM_ORDER_RECONCILE@2':'VMM.ORDER.RECONCILE.REQUEST',
    'VMM_ALGO_KILL@2':'VMM.ALGO.KILL.REQUEST',
    'VMM_ALGO_RESUME@2':'VMM.ALGO.RESUME.REQUEST',
    'VMM_EXCEPTION_ACK@2':'VMM.EXCEPTION.ACKNOWLEDGE.REQUEST'
  };
  for(const [key,action] of Object.entries(expected)){
    assert.ok(defs.has(key),key);
    assert.equal(defs.get(key).action,action,key);
    assert.equal(defs.get(key).profile,'HUMAN_VISUAL',key);
  }
});

test('workspace journey has dealing, institutional, treasury and exceptions states',()=>{
  const plan=pkg.journeyPlans[0];
  assert.equal(plan.initialState,'DEALING');
  assert.deepEqual(plan.states.map(s=>s.stateId).sort(),['DEALING','EXCEPTIONS','INSTITUTIONAL','TREASURY']);
  const triggers=new Set(plan.transitions.map(t=>t.trigger));
  for(const t of ['VMM.WORKSPACE.DEALING','VMM.WORKSPACE.INSTITUTIONAL','VMM.WORKSPACE.TREASURY','VMM.WORKSPACE.EXCEPTIONS']) assert.ok(triggers.has(t),t);
});

test('compiled definitions contain no VMM implementation object references',()=>{
  const text=JSON.stringify(pkg);
  for(const forbidden of ['VMMMarketMaker','VMMExecutionService','VMMInstitutionalSyntheticService','VMMAccountingService','FederationBankMerchantBank']) assert.equal(text.includes(forbidden),false,forbidden);
});
