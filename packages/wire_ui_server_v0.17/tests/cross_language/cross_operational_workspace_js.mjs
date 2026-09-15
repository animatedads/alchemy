import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const jsSrc=process.env.WIRE_UI_JS_SRC;
if(!jsSrc) throw new Error('WIRE_UI_JS_SRC required');
const api=await import(pathToFileURL(path.join(jsSrc,'src/index.js')).href);
const { CaptureTransport, Comms, DefinitionRegistry, MemoryRenderer, WireUIRuntime, adaptServerDefinition, makeEnvelope, MessageKind }=api;
const rex=process.env.REXX || 'rexx';
const serverScript=path.join(path.dirname(new URL(import.meta.url).pathname),'cross_operational_workspace_server.rex');
const p=spawnSync(rex,[serverScript],{encoding:'utf8',env:process.env});
if(p.status!==0) throw new Error(`ooRexx workspace fixture failed (${p.status}): ${p.stdout}\n${p.stderr}`);
const lines=p.stdout.trim().split(/\r?\n/).filter(Boolean);
const tagged=(tag)=>lines.filter(l=>l.startsWith(tag+' ')).map(l=>JSON.parse(l.slice(tag.length+1)));
const defs=tagged('DEF'), snap=tagged('SNAP')[0], patches=tagged('PATCH');
assert.equal(defs.length,3); assert.equal(patches.length,6);

const transport=new CaptureTransport();
const comms=new Comms({transport,source:'browser',destination:'server'});
transport.start(env=>comms.receive(env)); comms.connected=true;
const definitions=new DefinitionRegistry();
for(const d of defs) definitions.install(adaptServerDefinition(d));
const renderer=new MemoryRenderer({definitions});
const runtime=new WireUIRuntime({comms,definitions,renderer,serverSemantic:true,ownership:{}});
let seq=1;
transport.inject(makeEnvelope({kind:MessageKind.UI_VIEW_SNAPSHOT,payload:snap,sequence:seq++,source:'server',destination:'browser'}));
await new Promise(r=>setTimeout(r,5));
for(const patch of patches){
  transport.inject(makeEnvelope({kind:MessageKind.UI_VIEW_PATCH,payload:patch,sequence:seq++,source:'server',destination:'browser'}));
  await new Promise(r=>setTimeout(r,5));
}
assert.equal(runtime.revision,6);
assert.equal(renderer.getInstance('C-55201'),null);
const positions=renderer.getInstance('positions');
assert.deepEqual(positions.children,['C-77881']);
const row=renderer.getInstance('C-77881');
assert.equal(row.slots.economicState,'HEDGED');
assert.equal(row.slots.severity,'WARNING');
assert.equal(row.slots.riskSummary,'COLLATERAL SHORTFALL');
assert.equal(positions.slots.portfolioSeverity,'WARNING');
assert.equal(positions.slots.attentionCount,1);
console.log('PASS ooRexx <-> JS operational workspace collection patches');
