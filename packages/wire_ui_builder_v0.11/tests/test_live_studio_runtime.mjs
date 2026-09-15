import path from 'node:path';
import {spawn} from 'node:child_process';
import {pathToFileURL} from 'node:url';

const builderRoot=path.resolve(process.env.WUIB_BUILDER_ROOT??path.join(import.meta.dirname,'..'));
const jsRoot=need('WUIB_JS_ROOT');
need('WUIB_GATEWAY_ROOT');
need('WUIB_REXX');

function need(name){
  const value=process.env[name];
  if(!value) throw new Error(`${name} required`);
  return path.resolve(value);
}
function sleep(ms){return new Promise(resolve=>setTimeout(resolve,ms));}
async function waitFor(fn,label,timeout=12000){
  const end=Date.now()+timeout;
  let last=null;
  while(Date.now()<end){
    try{const value=fn(); if(value)return value;}catch(error){last=error;}
    await sleep(20);
  }
  throw new Error(`timeout waiting for ${label}${last?`: ${last.message}`:''}`);
}
function lines(stream,onLine){
  let buf=''; stream.setEncoding('utf8');
  stream.on('data',chunk=>{buf+=chunk; for(;;){const n=buf.indexOf('\n'); if(n<0)break; const line=buf.slice(0,n).replace(/\r$/,''); buf=buf.slice(n+1); onLine(line);}});
  stream.on('end',()=>{if(buf)onLine(buf);});
}
async function stop(child){
  if(!child||child.exitCode!==null)return;
  child.kill('SIGTERM');
  await Promise.race([new Promise(resolve=>child.once('exit',resolve)),sleep(1500)]);
  if(child.exitCode===null) child.kill('SIGKILL');
}

let host=null,comms=null;
const stdout=[]; const stderr=[];
try{
  host=spawn(process.execPath,[path.join(builderRoot,'tools','builder-live-host.mjs'),'--port','0','--json'],{
    cwd:builderRoot, env:{...process.env,WUIB_BUILDER_ROOT:builderRoot}, stdio:['ignore','pipe','pipe']
  });
  let ready=null;
  lines(host.stdout,line=>{stdout.push(line); try{const v=JSON.parse(line); if(v?.event==='builder-live-ready')ready=v;}catch{}});
  lines(host.stderr,line=>stderr.push(line));
  host.once('exit',(code,signal)=>{if(!ready)stderr.push(`host exited before ready code=${code} signal=${signal}`);});
  await waitFor(()=>ready,'live host readiness',20000);

  const healthResponse=await fetch(ready.healthUrl,{cache:'no-store'});
  if(!healthResponse.ok) throw new Error(`health endpoint ${healthResponse.status}`);
  const health=await healthResponse.json();
  if(health.runtime!=='ooRexx/WireUIServer/QueueFabric') throw new Error(`unexpected health runtime ${health.runtime}`);
  if(health.targetProjectId!=='VISUAL_WORKSPACE') throw new Error(`unexpected health target ${health.targetProjectId}`);

  const indexResponse=await fetch(ready.url,{cache:'no-store'});
  if(!indexResponse.ok) throw new Error(`Builder index ${indexResponse.status}`);
  const html=await indexResponse.text();
  if(!html.includes('Studio v0.11')) throw new Error('live Builder shell is not v0.11');

  const bootstrap=await (await fetch(new URL('wire-ui/bootstrap',ready.url),{cache:'no-store'})).json();
  for(const key of ['gatewayUrl','moduleUrl','outboundQueue']) if(!bootstrap[key]) throw new Error(`bootstrap missing ${key}`);
  for(const key of ['applicationId','sessionId','accessPointId']) if(!bootstrap.ownership?.[key]) throw new Error(`bootstrap ownership missing ${key}`);

  const api=await import(pathToFileURL(path.join(jsRoot,'src','index.js')).href);
  const {QueueFabricGatewayTransport,Comms,DefinitionRegistry,MemoryRenderer,WireUIRuntime,RenderProfileController,MemoryDefinitionCache}=api;
  const transport=new QueueFabricGatewayTransport({
    url:bootstrap.gatewayUrl,
    outboundQueue:bootstrap.outboundQueue,
    ownership:bootstrap.ownership,
    WebSocketImpl:globalThis.WebSocket,
    putResultMode:'required'
  });
  comms=new Comms({transport,source:bootstrap.ownership.accessPointId,destination:bootstrap.outboundQueue});
  const definitions=new DefinitionRegistry();
  const renderer=new MemoryRenderer({definitions});
  const profile=new RenderProfileController({
    comms,definitions,definitionCache:new MemoryDefinitionCache(),renderer,
    siteId:bootstrap.siteId??'WIRE_UI_BUILDER_STUDIO',
    capabilities:{viewportClass:'large',pointer:'fine',reducedMotion:false,colourScheme:'light',features:{dialog:true,adoptedStyleSheets:true,resizeObserver:true}}
  });
  const runtime=new WireUIRuntime({comms,definitions,renderer,serverSemantic:true,renderProfile:profile,ownership:bootstrap.ownership});
  await comms.connect(profile.helloPayload({accessPointId:bootstrap.ownership.accessPointId}));

  const project=await waitFor(()=>renderer.getInstance('project'),'authoritative project instance');
  const canvas=await waitFor(()=>renderer.getInstance('composition-canvas'),'authoritative composition canvas');
  if(project.slots.projectId!=='VISUAL_WORKSPACE') throw new Error(`unexpected projectId ${project.slots.projectId}`);
  if(Number(project.slots.revision)!==24) throw new Error(`expected target revision 24, got ${project.slots.revision}`);
  if(Number(project.slots.draftCount)!==24) throw new Error(`expected 24 target drafts, got ${project.slots.draftCount}`);
  if(!Array.isArray(canvas.slots.items)||canvas.slots.items.length<1) throw new Error('initial SEARCH canvas is empty');
  if(canvas.slots.items.some(item=>item.stateId!=='SEARCH')) throw new Error('initial canvas is not scoped to SEARCH');

  await waitFor(()=>definitions.definitions.size===23,'all 23 authorised Studio definitions');
  if(!definitions.has('WUIB_SOURCE_FILES',1)) throw new Error('DESIGN manifest omitted WUIB_SOURCE_FILES@1');

  renderer.emitAction('flow-map','FLOW.SELECT',{id:'MAIN_FLOW|SUMMARY'});
  await waitFor(()=>renderer.getInstance('preview-summary')?.slots?.journeyState==='SUMMARY','authoritative FLOW.SELECT state change');
  const summaryCanvas=await waitFor(()=>{
    const c=renderer.getInstance('composition-canvas');
    return Array.isArray(c?.slots?.items)&&c.slots.items.length>0&&c.slots.items.every(item=>item.stateId==='SUMMARY')?c:null;
  },'SUMMARY-scoped canvas');

  const beforeRevision=Number(renderer.getInstance('project').slots.revision);
  const before=summaryCanvas.slots.items.find(item=>Number(item.span)<12)??summaryCanvas.slots.items[0];
  const beforeSpan=Number(before.span);
  const wantedSpan=beforeSpan<12?beforeSpan+1:beforeSpan-1;
  renderer.emitAction('composition-canvas','DESIGN.COMPOSITION.RESIZE',{id:before.id,span:wantedSpan});
  await waitFor(()=>Number(renderer.getInstance('project')?.slots?.revision)===beforeRevision+1,'semantic resize draft revision');
  const changed=await waitFor(()=>renderer.getInstance('composition-canvas')?.slots?.items?.find(item=>item.id===before.id&&Number(item.span)===wantedSpan),'authoritative resized placement');
  if(!changed) throw new Error('semantic resize did not return authoritative placement');

  // v0.11 SOURCE is a genuine Server v0.16 authoritative workspace.  Prove the
  // real transport sees a bounded window, stable row identity, selection and a
  // membership-scope change rather than a whole-catalogue DOM dump.
  const initialSourceWindowRevision=Number(renderer.getInstance('source-files')?.slots?.windowRevision??0);
  renderer.emitAction('tool-nav','STUDIO.NAVIGATE',{value:'SOURCE'});
  const sourceWindow=await waitFor(()=>{
    const w=renderer.getInstance('source-files');
    return w?.children?.length>0 && Number(w.slots?.windowTotalCount)>0 && Number(w.slots?.windowRevision)>initialSourceWindowRevision ? w : null;
  },'SOURCE authoritative collection window after navigation');
  if(sourceWindow.children.length>Number(sourceWindow.slots.windowLimit)) throw new Error('SOURCE window exceeded authoritative limit');
  const firstSourceId=sourceWindow.children[0];
  const firstSource=renderer.getInstance(firstSourceId);
  if(!firstSource?.slots?.label) throw new Error('SOURCE row missing stable logical path');
  renderer.emitAction(firstSourceId,'SOURCE.OPEN',{});
  await waitFor(()=>Boolean(renderer.getInstance('source-detail')?.slots?.visible) && renderer.getInstance('source-detail')?.slots?.path===firstSource.slots.label,'SOURCE semantic selection/detail');
  if(Number(renderer.getInstance('source-detail').slots.selectionRevision)<1) throw new Error('SOURCE selection revision did not advance');

  renderer.emitAction('source-window-control','SOURCE.WINDOW',{filter:'WireUIBuilderApplication.cls',sortRef:'PATH',direction:'ASC',offset:99,limit:10});
  const filtered=await waitFor(()=>{
    const w=renderer.getInstance('source-files');
    if(!w || w.slots?.filterRef!=='WireUIBuilderApplication.cls' || Number(w.slots?.windowOffset)!==0 || w.children?.length!==1) return null;
    const row=renderer.getInstance(w.children[0]);
    return row?.slots?.label?.endsWith('/integration/WireUIBuilderApplication.cls') ? w : null;
  },'SOURCE filtered membership window');
  if(!filtered) throw new Error('SOURCE filtered window not returned');
  await waitFor(()=>!Boolean(renderer.getInstance('source-detail')?.slots?.visible),'SOURCE stale selection invalidation');
  if(runtime.revision==null) throw new Error('WireUIRuntime did not establish a view revision');

  console.log(`PASS test_live_studio_runtime real ooRexx/Server/QueueFabric/gateway round-trip; 23 definitions; FLOW.SELECT; RESIZE ${beforeSpan}->${wantedSpan}; SOURCE window/selection/filter; target 24->${beforeRevision+1}`);
}catch(error){
  console.error(`FAIL test_live_studio_runtime: ${error.stack||error}`);
  if(stderr.length) console.error('HOST STDERR\n'+stderr.slice(-30).join('\n'));
  if(stdout.length) console.error('HOST STDOUT\n'+stdout.slice(-30).join('\n'));
  process.exitCode=1;
}finally{
  try{await comms?.close();}catch{}
  await stop(host);
}
