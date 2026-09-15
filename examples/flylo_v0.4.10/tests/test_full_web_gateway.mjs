import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const jsRoot=process.env.WIRE_UI_JS_ROOT;
const gatewayRoot=process.env.WIRE_UI_WEB_GATEWAY_ROOT;
if(!jsRoot) throw new Error('WIRE_UI_JS_ROOT is required');
if(!gatewayRoot) throw new Error('WIRE_UI_WEB_GATEWAY_ROOT is required');
const api=await import(pathToFileURL(path.join(jsRoot,'src/index.js')).href);
const {QueueFabricGatewayTransport,Comms,DefinitionRegistry,BrowserRenderer,WireUIRuntime,RenderProfileController,WireUIJourneyController,ObservationPlan}=api;
const {QueueBackendClient}=await import(pathToFileURL(path.join(gatewayRoot,'node/queue-backend-client.mjs')).href);
const {QueueFabricWebSocketEdge}=await import(pathToFileURL(path.join(gatewayRoot,'node/websocket-edge.mjs')).href);

class FakeNode {
  constructor(tag,document){this.tagName=String(tag).toUpperCase();this.ownerDocument=document;this.children=[];this.attributes=new Map();this.listeners=new Map();this.textContent='';this.hidden=false;this.disabled=false;this.value='';this.checked=false;this.className='';this.parent=null;}
  setAttribute(n,v){this.attributes.set(n,String(v));if(n==='value')this.value=String(v);}
  removeAttribute(n){this.attributes.delete(n);}
  addEventListener(n,h){this.listeners.set(n,h);}
  appendChild(c){c.remove();c.parent=this;this.children.push(c);}
  insertBefore(c,b){c.remove();c.parent=this;const i=this.children.indexOf(b);if(i<0)this.children.push(c);else this.children.splice(i,0,c);}
  replaceChildren(...cs){for(const c of this.children)c.parent=null;this.children=[];for(const c of cs)this.appendChild(c);}
  remove(){if(!this.parent)return;this.parent.children=this.parent.children.filter(c=>c!==this);this.parent=null;}
  fire(n,event={}){this.listeners.get(n)?.({currentTarget:this,target:event.target??this,preventDefault(){},...event});}
}
class FakeDocument {createElement(tag){return new FakeNode(tag,this);}}
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function waitFor(fn,label,timeout=8000){const start=Date.now();while(Date.now()-start<timeout){const v=fn();if(v)return v;await wait(10);}throw new Error(`timed out waiting for ${label}`);}
function field(live,name){return [...live.nodes.values()].find(n=>n.attributes?.get('name')===name);}
function setFields(live,values){for(const [name,value] of Object.entries(values)){const node=field(live,name);assert.ok(node,`missing field ${name}`);if(node.attributes.get('type')==='checkbox')node.checked=Boolean(value);else node.value=String(value);}}
function submit(live){live.root.fire('submit');}
function slotNode(definitions,live,name){const def=definitions.get(live.definitionId,live.definitionVersion);const spec=def.slots.find(s=>s.name===name);assert.ok(spec,`missing slot ${name}`);return live.nodes.get(spec.target);}
function actionButton(live){return live.nodes.get('action');}

const root=path.resolve(import.meta.dirname,'..');
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'flylo-web-e2e-'));
const portFile=path.join(tmp,'port'),stopFile=path.join(tmp,'stop'),resultFile=path.join(tmp,'result.json');
const env={...process.env,PATH:`${process.env.OOREXX_BIN}:${process.env.PATH}`,LD_LIBRARY_PATH:`${process.env.OOREXX_LIB}:${process.env.LD_LIBRARY_PATH??''}`};
const rex=spawn(path.join(process.env.OOREXX_BIN,'rexx'),[path.join(root,'tests','flylo_web_gateway_fixture.rex'),portFile,stopFile,resultFile],{env,stdio:['ignore','pipe','pipe']});
let stdout='',stderr='';rex.stdout.on('data',d=>stdout+=d);rex.stderr.on('data',d=>stderr+=d);
for(let i=0;i<600&&!fs.existsSync(portFile);i++)await wait(25);
assert.ok(fs.existsSync(portFile),`FlyLo ooRexx fixture did not start: ${stdout}\n${stderr}`);

const backend=new QueueBackendClient({port:Number(fs.readFileSync(portFile,'utf8').trim()),bridgeToken:'bridge-secret'});
const edge=new QueueFabricWebSocketEdge({backend,inboundQueue:'WIREUI.IN.WEB',host:'127.0.0.1',port:0,path:'/wire-ui',pathToken:'browser-token',pollMs:5});
await edge.start();

const ownership={applicationId:'FLYLO-APP',sessionId:'S1',accessPointId:'WEB'};
const transport=new QueueFabricGatewayTransport({url:`ws://127.0.0.1:${edge.port}/wire-ui?token=browser-token`,outboundQueue:'WIREUI.IN.WEB',ownership,putResultMode:'required'});
const comms=new Comms({transport,source:'FLYLO.WEB',destination:'WIREUI.IN.WEB'});
const definitions=new DefinitionRegistry();const document=new FakeDocument();const mount=document.createElement('main');
const renderer=new BrowserRenderer({definitions,mount,document});
const profile=new RenderProfileController({comms,definitions,renderer,siteId:'FLYLO_WEB',capabilities:{viewportClass:'large',pointer:'fine',features:{dialog:true}}});
const runtime=new WireUIRuntime({comms,definitions,renderer,serverSemantic:true,renderProfile:profile,ownership});
new WireUIJourneyController({comms,runtime});new ObservationPlan({comms});
await comms.connect(profile.helloPayload(ownership));

await waitFor(()=>renderer.instances.get('search'),'initial FlyLo search');
assert.ok(renderer.instances.has('assistant-trigger'),'Ask FlyLo trigger prefetched/available');
const search=renderer.instances.get('search');
setFields(search,{origin:'PIK',destination:'EWR',date:'2026-09-01',passengers:1});submit(search);
await waitFor(()=>renderer.instances.get('offers')?.root?.children?.length,'server-owned offer projection');
const offers=renderer.instances.get('offers');
// The server emitted three ordered search-result patches. Do not manufacture a
// stale action in the acceptance fixture by clicking before the browser has
// applied the final search-visible transition.
await waitFor(()=>renderer.instances.get('search')?.root?.hidden===true,'complete search transition');
offers.root.fire('click',{target:offers.root.children[0]});

await waitFor(()=>renderer.instances.get('passengers')&&renderer.instances.get('offers')?.root?.hidden===true,'passenger form');
const passengers=renderer.instances.get('passengers');
assert.equal(field(passengers,'saleId').attributes.get('type'),'hidden');
setFields(passengers,{saleId:'BROWSER-LIE',givenName:'Walter',familyName:'White',email:'walter@example.invalid'});submit(passengers);
await waitFor(()=>renderer.instances.get('extras'),'ancillary choice form');

/* Ask FlyLo after passenger capture: permitted name may enter context, email may not. */
renderer.instances.get('assistant-trigger').root.fire('click');
await waitFor(()=>renderer.instances.get('assistant')&&!renderer.instances.get('assistant').root.hidden,'assistant visible');
const assistant=renderer.instances.get('assistant');
setFields(assistant,{message:'What extras might be useful?'});actionButton(assistant).fire('click');
await waitFor(()=>slotNode(definitions,renderer.instances.get('assistant'),'answer').textContent.includes('nothing has been added'),'assistant answer');

const extras=renderer.instances.get('extras');
setFields(extras,{saleId:'BROWSER-LIE',CABIN_BAG:true,CHECKED_BAG:false,SEAT_SELECTION:true,PRIORITY_BOARDING:false});submit(extras);
await waitFor(()=>renderer.instances.get('review'),'authoritative review');
const review=renderer.instances.get('review');
assert.equal(slotNode(definitions,review,'totalMinor').textContent,'24200');
actionButton(review).fire('click');

await waitFor(()=>renderer.instances.get('payment'),'payment form');
const payment=renderer.instances.get('payment');
assert.equal(field(payment,'saleId').attributes.get('type'),'hidden');
setFields(payment,{saleId:'BROWSER-LIE',paymentMethodToken:'tok_fixture',totalMinor:1,currency:'XXX'});submit(payment);
await waitFor(()=>renderer.instances.get('confirmation'),'booking confirmation');
const confirmation=renderer.instances.get('confirmation');
assert.equal(slotNode(definitions,confirmation,'status').textContent,'CONFIRMED');
assert.notEqual(slotNode(definitions,confirmation,'bookingRef').textContent,'');

await comms.close();await wait(50);await edge.stop();fs.writeFileSync(stopFile,'stop');
await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error(`ooRexx fixture timeout: ${stdout}\n${stderr}`)),7000);rex.once('exit',code=>{clearTimeout(timer);code===0?resolve():reject(new Error(`ooRexx fixture exit ${code}: ${stdout}\n${stderr}`));});});
assert.ok(fs.existsSync(resultFile),'missing FlyLo fixture result');
const evidence=JSON.parse(fs.readFileSync(resultFile,'utf8'));
assert.match(evidence.assistantPrompt,/Walter White/);
assert.doesNotMatch(evidence.assistantPrompt,/walter@example\.invalid/);
assert.equal(evidence.authoritativeTotalMinor,24200);
assert.equal(evidence.bookingStatus,'CONFIRMED');
console.log('FLYLO REAL QUEUE FABRIC WEB GATEWAY FULL BOOKING + ASSISTANT: OK');
