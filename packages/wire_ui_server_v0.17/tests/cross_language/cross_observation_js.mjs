import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const jsSrc = process.env.WIRE_UI_JS_SRC;
if (!jsSrc) throw new Error('WIRE_UI_JS_SRC must point to Alchemy Wire UI JS package root');
const api = await import(pathToFileURL(path.join(jsSrc, 'src/index.js')).href);
const { CaptureTransport, Comms, ObservationPlan, envelopeToQueuePayload } = api;
const rex = process.env.REXX || 'rexx';
const serverScript = path.join(path.dirname(new URL(import.meta.url).pathname), 'cross_observation_server.rex');
function runServer(args) {
  const p=spawnSync(rex,[serverScript,...args],{encoding:'utf8',env:process.env});
  if (p.status!==0) throw new Error(`ooRexx observation cross-wire failed (${p.status}): ${p.stdout}\n${p.stderr}`);
  return p.stdout.trim().split(/\r?\n/).filter(Boolean);
}
function tagged(lines,tag){return lines.filter(l=>l.startsWith(tag+' ')).map(l=>l.slice(tag.length+1));}
const lines=runServer(['emit']);
const plan=JSON.parse(tagged(lines,'PLAN')[0]);
assert.equal(plan.type,'OBSERVATION_PLAN');
assert.equal(plan.subscription,'OBS.CANCEL');
assert.equal(plan.revision,3); // ooRexx JSON helper emits numeric-looking version as JSON number
assert.deepEqual(plan.points[0].allowedFields,['elementInstance','flowRef','state']);

const transport=new CaptureTransport();
const comms=new Comms({transport,source:'OLA-AP',destination:'WIREUI.IN.OLA-AP'});
transport.start((envelope)=>comms.receive(envelope));
comms.connected=true;
const observations=new ObservationPlan({comms});
observations.install(plan);

let disabledFactoryCalled=false;
const disabled=await observations.observe('UNSUBSCRIBED_POINT',()=>{disabledFactoryCalled=true; return {x:1};});
assert.equal(disabled,false);
assert.equal(disabledFactoryCalled,false);

transport.sent.length=0;
const emitted=await observations.observe('CANCEL_FLOW_ENTERED',{
  flowRef:'CANCEL-77', elementInstance:'cancelAction', state:'ENTERED', secretDOM:'div:nth-child(7)'
});
assert.equal(emitted,true);
const payload=envelopeToQueuePayload(transport.sent.at(-1));
assert.equal(payload.type,'INTERACTION_OBSERVATION');
assert.equal(payload.subscription,'OBS.CANCEL');
assert.equal(payload.point,'CANCEL_FLOW_ENTERED');
assert.equal(payload.observation.flowRef,'CANCEL-77');
assert.equal(Object.hasOwn(payload.observation,'secretDOM'),false);

const result=runServer(['accept',payload.subscription,String(payload.subscriptionRevision),payload.point,payload.purpose,payload.evidenceStrength,payload.observation.flowRef,payload.observation.elementInstance,payload.observation.state]);
assert.ok(result.some(l=>l==='RESULT INTERACTION_OBSERVATION_ACCEPTED CANCEL_FLOW_ENTERED CANCEL-77 ENTERED'));
console.log('PASS ooRexx <-> configured JS runtime positive-list observation cross-wire');
