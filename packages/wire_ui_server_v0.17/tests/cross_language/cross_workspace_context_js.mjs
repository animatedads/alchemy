import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const jsSrc=process.env.WIRE_UI_JS_SRC;
if(!jsSrc) throw new Error('WIRE_UI_JS_SRC required');
const api=await import(pathToFileURL(path.join(jsSrc,'src/index.js')).href);
const { CaptureTransport, Comms, DefinitionRegistry, MemoryRenderer, WireUIRuntime, envelopeToQueuePayload }=api;
const rex=process.env.REXX || 'rexx';
const serverScript=path.join(path.dirname(new URL(import.meta.url).pathname),'cross_workspace_context_server.rex');
function run(args){
  const p=spawnSync(rex,[serverScript,...args],{encoding:'utf8',env:process.env});
  if(p.status!==0) throw new Error(`ooRexx workspace-context fixture failed (${p.status}): ${p.stdout}\n${p.stderr}`);
  return p.stdout.trim().split(/\r?\n/).filter(Boolean);
}
const lines=run(['emit']);
const ctx=JSON.parse(lines.find(l=>l.startsWith('CONTEXT ')).slice(8));
const revision=Number(lines.find(l=>l.startsWith('REVISION ')).split(' ')[1]);
assert.equal(ctx.workspaceRef,'POSITIONS');
assert.deepEqual(ctx.selectedIds,['P-100','P-200']);
assert.equal(ctx.resultRevision,1);
assert.ok(ctx.resultCurrent);

const transport=new CaptureTransport();
const comms=new Comms({transport,source:'AP',destination:'server'});
transport.start(env=>comms.receive(env)); comms.connected=true;
const definitions=new DefinitionRegistry();
const renderer=new MemoryRenderer({definitions});
const runtime=new WireUIRuntime({comms,definitions,renderer,ownership:{applicationId:'APP',sessionId:'SESSION',accessPointId:'AP'}});
runtime.viewRef='MB.WORKSPACE'; runtime.revision=revision;
await runtime.sendSemanticAction('POSITION.BULK.CLOSE',{instanceId:'bulk-close',detail:{workspaceContext:ctx}});
const semantic=envelopeToQueuePayload(transport.sent.at(-1),{applicationId:'APP',sessionId:'SESSION',accessPointId:'AP'});
assert.deepEqual(semantic.detail.workspaceContext,ctx);
const ids=semantic.detail.workspaceContext.selectedIds.join(',');
const accepted=run(['accept',String(ctx.queryRevision),String(ctx.scopeRevision),String(ctx.orderRevision),String(ctx.selectionRevision),String(ctx.resultRevision),String(ctx.resultQueryRevision),String(ctx.resultScopeRevision),String(ctx.resultOrderRevision),ids]);
assert.ok(accepted.some(l=>l==='RESULT WORKSPACE_COMMAND_ACCEPTED 2'));
console.log('PASS ooRexx <-> JS authoritative workspace command context');
