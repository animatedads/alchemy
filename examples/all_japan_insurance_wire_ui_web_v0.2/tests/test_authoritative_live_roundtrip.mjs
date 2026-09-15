import assert from 'node:assert/strict';
import net from 'node:net';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'..');
const rexx=process.env.AJI_OOREXX;
if(!rexx) throw new Error('AJI_OOREXX is required');
const rexxLib=process.env.AJI_OOREXX_LIB||'';

class FakeNode {
  constructor(tag){this.tagName=String(tag).toUpperCase();this.children=[];this.attributes=new Map();this.listeners=new Map();this.textContent='';this.hidden=false;this.disabled=false;this.value='';this.className='';this.parent=null;this.ownerDocument=null;}
  setAttribute(n,v){this.attributes.set(n,String(v));if(n==='value')this.value=String(v);}
  removeAttribute(n){this.attributes.delete(n);}
  addEventListener(n,h){this.listeners.set(n,h);}
  appendChild(c){c.remove();c.parent=this;this.children.push(c);}
  insertBefore(c,b){c.remove();c.parent=this;const i=this.children.indexOf(b);if(i<0)this.children.push(c);else this.children.splice(i,0,c);}
  replaceChildren(...cs){for(const c of this.children)c.parent=null;this.children=[];for(const c of cs)this.appendChild(c);}
  remove(){if(!this.parent)return;this.parent.children=this.parent.children.filter(c=>c!==this);this.parent=null;}
  get parentElement(){return this.parent;}
}
class FakeStyle{constructor(){this.values=new Map();}setProperty(n,v){this.values.set(n,String(v));}removeProperty(n){this.values.delete(n);}getPropertyValue(n){return this.values.get(n)??'';}}
class FakeRoot{constructor(){this.style=new FakeStyle();this.attributes=new Map();}setAttribute(n,v){this.attributes.set(n,String(v));}}
class FakeDocument{constructor(){this.documentElement=new FakeRoot();}createElement(tag){const n=new FakeNode(tag);n.ownerDocument=this;return n;}}

const freePort=()=>new Promise((resolve,reject)=>{const s=net.createServer();s.once('error',reject);s.listen(0,'127.0.0.1',()=>{const p=s.address().port;s.close(()=>resolve(p));});});
const port=await freePort();
const args=[path.join(root,'tools','aji-authoritative-host.mjs'),'--port',String(port),'--rexx',rexx,'--json'];
if(rexxLib)args.push('--rexx-lib',rexxLib);
const host=spawn(process.execPath,args,{cwd:root,env:process.env,stdio:['ignore','pipe','pipe']});
let stderr='';host.stderr.setEncoding('utf8');host.stderr.on('data',d=>stderr+=d);
const ready=await new Promise((resolve,reject)=>{let b='';const t=setTimeout(()=>reject(new Error(`authority timeout: ${stderr}`)),15000);host.stdout.setEncoding('utf8');host.stdout.on('data',d=>{b+=d;for(;;){const n=b.indexOf('\n');if(n<0)break;const line=b.slice(0,n).trim();b=b.slice(n+1);if(!line)continue;try{const v=JSON.parse(line);if(v.event==='aji-authoritative-wire-ui-ready'){clearTimeout(t);resolve(v);return;}}catch{}}});host.once('exit',c=>reject(new Error(`authority exited ${c}: ${stderr}`)));});
try{
  const response=await fetch(ready.bootstrapUrl,{headers:{accept:'application/json'}});
  assert.equal(response.status,200);
  const config=await response.json();
  assert.equal(config.ownership.applicationId,'ALL-JAPAN-INSURANCE-OPERATIONS');
  assert.equal(config.outboundQueue,'WIREUI.IN.AJI-WEB');
  assert.match(config.gatewayUrl,/^ws:\/\/127\.0\.0\.1:/);

  const api=await import(pathToFileURL(path.join(root,'vendor','alchemy_wire_ui_js_v0.4-dev4','src','index.js')).href);
  const {QueueFabricGatewayTransport,Comms,DefinitionRegistry,BrowserRenderer,WireUIRuntime,RenderProfileController,WireUIJourneyController,ObservationPlan,MaterialController}=api;
  const transport=new QueueFabricGatewayTransport({url:config.gatewayUrl,outboundQueue:config.outboundQueue,ownership:config.ownership,putResultMode:'required'});
  const comms=new Comms({transport,source:config.ownership.accessPointId,destination:config.outboundQueue});
  const definitions=new DefinitionRegistry();const document=new FakeDocument();const mount=document.createElement('main');
  const material=new MaterialController({comms,document});const renderer=new BrowserRenderer({definitions,mount,document});
  const profile=new RenderProfileController({comms,definitions,renderer,siteId:config.siteId});
  const runtime=new WireUIRuntime({comms,definitions,renderer,serverSemantic:true,renderProfile:profile,ownership:config.ownership});
  new WireUIJourneyController({comms,runtime});new ObservationPlan({comms});
  await comms.connect(profile.helloPayload({accessPointId:config.ownership.accessPointId}));
  for(let i=0;i<300&&(!renderer.instances.has('portfolio')||!renderer.instances.has('policy-list'));i++) await new Promise(r=>setTimeout(r,10));
  assert.ok(renderer.instances.has('portfolio'),'authoritative portfolio did not render');
  assert.ok(renderer.instances.has('policy-list'),'authoritative policy list did not render');
  assert.equal(material.current?.materialId,'AJI_OPERATIONS_MATERIAL');
  const policies=renderer.instances.get('policy-list');
  assert.equal(policies.root.children.length,3);
  const home=policies.root.children.find(c=>String(c.textContent).includes('AJI-HOME-2026-018441'));
  assert.ok(home,'HOME policy absent from server-issued collection');
  const click=policies.root.listeners.get('click');assert.equal(typeof click,'function');
  click({target:home,currentTarget:policies.root,preventDefault(){}});
  for(let i=0;i<400&&!renderer.instances.has('accounting-detail');i++) await new Promise(r=>setTimeout(r,10));
  assert.ok(renderer.instances.has('policy-detail'),'selected policy detail not rendered');
  assert.ok(renderer.instances.has('billing-detail'),'selected billing detail not rendered');
  assert.ok(renderer.instances.has('claim-detail'),'selected claim detail not rendered');
  assert.ok(renderer.instances.has('accounting-detail'),'selected accounting detail not rendered');
  const detail=renderer.instances.get('policy-detail');
  const visible=[...detail.nodes.values()].map(n=>String(n.textContent||'')).join('|');
  assert.match(visible,/AJI-HOME-2026-018441/);
  assert.match(visible,/AJI-HOME-CONTRACT\/2026A/);
  const claim=renderer.instances.get('claim-detail');
  const claimText=[...claim.nodes.values()].map(n=>String(n.textContent||'')).join('|');
  assert.match(claimText,/480000/);
  await comms.close();
  console.log('PASS AJI authoritative bootstrap -> Queue Fabric -> Wire UI JS -> policy drill-down');
} finally {
  host.kill('SIGTERM');
  await new Promise(r=>setTimeout(r,250));
  if(!host.killed)host.kill('SIGKILL');
}
