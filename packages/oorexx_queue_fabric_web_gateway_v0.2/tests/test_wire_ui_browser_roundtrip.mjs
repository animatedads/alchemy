import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { QueueBackendClient } from '../node/queue-backend-client.mjs';
import { QueueFabricWebSocketEdge } from '../node/websocket-edge.mjs';

const jsRoot=process.env.WIRE_UI_JS_ROOT;
if(!jsRoot) throw new Error('WIRE_UI_JS_ROOT is required');
const api=await import(pathToFileURL(path.join(jsRoot,'src/index.js')).href);
const {QueueFabricGatewayTransport,Comms,DefinitionRegistry,BrowserRenderer,WireUIRuntime,RenderProfileController,WireUIJourneyController,ObservationPlan,MaterialController}=api;

class FakeNode {
  constructor(tag){this.tagName=String(tag).toUpperCase();this.children=[];this.attributes=new Map();this.listeners=new Map();this.textContent='';this.hidden=false;this.disabled=false;this.value='';this.className='';this.parent=null;this.ownerDocument=null;}
  setAttribute(n,v){this.attributes.set(n,String(v)); if(n==='value')this.value=String(v);}
  removeAttribute(n){this.attributes.delete(n);}
  addEventListener(n,h){this.listeners.set(n,h);}
  appendChild(c){c.remove();c.parent=this;this.children.push(c);}
  insertBefore(c,b){c.remove();c.parent=this;const i=this.children.indexOf(b);if(i<0)this.children.push(c);else this.children.splice(i,0,c);}
  replaceChildren(...cs){for(const c of this.children)c.parent=null;this.children=[];for(const c of cs)this.appendChild(c);}
  remove(){if(!this.parent)return;this.parent.children=this.parent.children.filter(c=>c!==this);this.parent=null;}
  fire(n){this.listeners.get(n)?.({currentTarget:this,preventDefault(){}});}
}
class FakeStyle { constructor(){this.values=new Map();} setProperty(n,v){this.values.set(n,String(v));} removeProperty(n){this.values.delete(n);} getPropertyValue(n){return this.values.get(n)??'';} }
class FakeRoot { constructor(){this.style=new FakeStyle();this.attributes=new Map();} setAttribute(n,v){this.attributes.set(n,String(v));} }
class FakeDocument { constructor(){this.documentElement=new FakeRoot();} createElement(tag){const n=new FakeNode(tag);n.ownerDocument=this;return n;} }

const root=path.resolve(import.meta.dirname,'..');
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'qfgw-wireui-'));
const portFile=path.join(tmp,'port'), stopFile=path.join(tmp,'stop'), resultFile=path.join(tmp,'result.json');
const env={...process.env,PATH:`${process.env.OOREXX_BIN}:${process.env.PATH}`,LD_LIBRARY_PATH:`${process.env.OOREXX_LIB}:${process.env.LD_LIBRARY_PATH??''}`};
const rex=spawn(path.join(process.env.OOREXX_BIN,'rexx'),[path.join(root,'tests','wire_ui_backend_fixture.rex'),portFile,stopFile,resultFile],{env,stdio:['ignore','pipe','pipe']});
let stderr='';rex.stderr.on('data',d=>stderr+=d);
for(let i=0;i<120&&!fs.existsSync(portFile);i++)await new Promise(r=>setTimeout(r,25));
assert.ok(fs.existsSync(portFile),`ooRexx fixture did not start: ${stderr}`);
const backend=new QueueBackendClient({port:Number(fs.readFileSync(portFile,'utf8').trim()),bridgeToken:'bridge-secret'});
const edge=new QueueFabricWebSocketEdge({backend,inboundQueue:'WIREUI.TEST.IN',host:'127.0.0.1',port:0,path:'/wire-ui',pathToken:'browser-token',pollMs:10});
await edge.start();

const transport=new QueueFabricGatewayTransport({url:`ws://127.0.0.1:${edge.port}/wire-ui?token=browser-token`,outboundQueue:'WIREUI.TEST.IN',ownership:{applicationId:'FLYLO-APP',sessionId:'FLYLO-SESSION',accessPointId:'TEST'},putResultMode:'required'});
const comms=new Comms({transport,source:'TEST',destination:'WIREUI.IN.TEST'});
const definitions=new DefinitionRegistry(); const document=new FakeDocument(); const mount=document.createElement('main');
const material=new MaterialController({comms,document});
const renderer=new BrowserRenderer({definitions,mount,document});
const profile=new RenderProfileController({comms,definitions,renderer,siteId:'FLYLO'});
const runtime=new WireUIRuntime({comms,definitions,renderer,serverSemantic:true,renderProfile:profile,ownership:{applicationId:'FLYLO-APP',sessionId:'FLYLO-SESSION',accessPointId:'TEST'}});
new WireUIJourneyController({comms,runtime}); new ObservationPlan({comms});
await comms.connect(profile.helloPayload({accessPointId:'TEST'}));
for(let i=0;i<200&&!renderer.instances.has('search');i++)await new Promise(r=>setTimeout(r,10));
assert.ok(renderer.instances.has('search'),'FlyLo search instance was not rendered');
assert.equal(material.current?.materialId,'FLYLO_MATERIAL','FlyLo material set was not applied');
assert.equal(document.documentElement.style.getPropertyValue('--wui-brand-pink'),'#ff2d88');
assert.equal(material.recipe('hero.search'),'brand.hero/search.card');
const live=renderer.instances.get('search');
assert.match(live.root.className,/wui-hero-search/);
assert.equal(live.root.attributes.get('data-wire-definition'),'FLYLO_SEARCH_FORM@1');
const field=(name)=>[...live.nodes.values()].find((node)=>node.attributes?.get('name')===name);
assert.equal(field('origin').value,'PIK');
assert.equal(field('destination').value,'EWR');
field('passengers').value='5';
live.root.fire('submit');
for(let i=0;i<200&&transport.pendingPuts.size;i++)await new Promise(r=>setTimeout(r,10));
assert.equal(transport.pendingPuts.size,0,'semantic search PUT did not complete');
for(let i=0;i<250&&!renderer.instances.has('offers');i++)await new Promise(r=>setTimeout(r,10));
assert.ok(renderer.instances.has('offers'),'FlyLo offers instance was not rendered');
const offerLive=renderer.instances.get('offers');
assert.match(offerLive.root.className,/wui-utility-card/);
assert.equal(offerLive.root.attributes.get('data-wire-definition'),'FLYLO_OFFER_CARDS@1');
assert.equal(offerLive.root.children.length,2);
const firstOffer=offerLive.root.children[0];
const offerClick=offerLive.root.listeners.get('click');
assert.equal(typeof offerClick,'function');
offerClick({currentTarget:offerLive.root,target:firstOffer,preventDefault(){}});
for(let i=0;i<200&&transport.pendingPuts.size;i++)await new Promise(r=>setTimeout(r,10));
assert.equal(transport.pendingPuts.size,0,'semantic selection PUT did not complete');
for(let i=0;i<250&&!renderer.instances.has('assistant');i++)await new Promise(r=>setTimeout(r,10));
assert.ok(renderer.instances.has('assistant'),'FlyLo assistant instance was not rendered');
const assistantLive=renderer.instances.get('assistant');
assert.match(assistantLive.root.className,/wui-assistant-panel/);
assert.equal(assistantLive.root.attributes.get('data-wire-definition'),'FLYLO_ASSISTANT@1');
const messageInput=[...assistantLive.nodes.values()].find((node)=>node.attributes?.get('name')==='message');
assert.ok(messageInput,'assistant message input absent');
messageInput.value='What optional extras would you suggest for five passengers?';
const assistantButton=assistantLive.nodes.get('action');
assert.ok(assistantButton,'assistant semantic action button absent');
assistantButton.fire('click');
for(let i=0;i<200&&transport.pendingPuts.size;i++)await new Promise(r=>setTimeout(r,10));
assert.equal(transport.pendingPuts.size,0,'semantic assistant PUT did not complete');
await comms.close(); await new Promise(r=>setTimeout(r,50)); await edge.stop();
fs.writeFileSync(stopFile,'stop');
await new Promise((resolve,reject)=>{rex.once('exit',code=>code===0?resolve():reject(new Error(`ooRexx fixture exit ${code}: ${stderr}`)));setTimeout(()=>reject(new Error(`ooRexx fixture timeout: ${stderr}`)),5000).unref();});
assert.ok(fs.existsSync(resultFile),'fixture did not capture browser action');
const captured=JSON.parse(fs.readFileSync(resultFile,'utf8'));
const action=captured.search;
assert.equal(action.type,'UI_ACTION'); assert.equal(action.action,'FLIGHT.SEARCH'); assert.equal(action.renderedRevision,7); assert.equal(action.viewRef,'FlyLo.Search');
assert.deepEqual(action.detail,{origin:'PIK',destination:'EWR',date:'2026-09-01',passengers:'5'});
assert.equal(action.applicationId,'FLYLO-APP'); assert.equal(action.sessionId,'FLYLO-SESSION');
const selection=captured.selection;
assert.equal(selection.type,'UI_ACTION'); assert.equal(selection.action,'FLIGHT.SELECT'); assert.equal(selection.renderedRevision,8); assert.equal(selection.viewRef,'FlyLo.Offers');
assert.deepEqual(selection.detail,{index:0,offerId:'OFF-7'});
assert.equal(selection.applicationId,'FLYLO-APP'); assert.equal(selection.sessionId,'FLYLO-SESSION');
const assistant=captured.assistant;
assert.equal(assistant.type,'UI_ACTION'); assert.equal(assistant.action,'ASSISTANT.ASK'); assert.equal(assistant.renderedRevision,9); assert.equal(assistant.viewRef,'FlyLo.Assistant');
assert.deepEqual(assistant.detail,{message:'What optional extras would you suggest for five passengers?'});
assert.equal(assistant.applicationId,'FLYLO-APP'); assert.equal(assistant.sessionId,'FLYLO-SESSION');
console.log('WIRE UI BROWSER SEARCH -> OFFERS -> SELECTION -> ASK OVER REAL QUEUE FABRIC: OK');
