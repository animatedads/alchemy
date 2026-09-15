import assert from 'node:assert/strict';
import fs from 'node:fs'; import os from 'node:os'; import path from 'node:path';
import {spawn} from 'node:child_process'; import {pathToFileURL} from 'node:url';

const root=path.resolve(import.meta.dirname,'..');
const gatewayRoot=process.env.WEB_GATEWAY_ROOT; if(!gatewayRoot)throw new Error('WEB_GATEWAY_ROOT required');
const {QueueBackendClient}=await import(pathToFileURL(path.join(gatewayRoot,'node/queue-backend-client.mjs')).href);
const {QueueFabricWebSocketEdge}=await import(pathToFileURL(path.join(gatewayRoot,'node/websocket-edge.mjs')).href);

class FakeStyle{constructor(){this.values=new Map()}setProperty(n,v){this.values.set(n,String(v))}removeProperty(n){this.values.delete(n)}getPropertyValue(n){return this.values.get(n)??''}}
class FakeClassList{constructor(node){this.node=node}add(...xs){const set=new Set(this.node.className.split(/\s+/).filter(Boolean));xs.forEach(x=>set.add(x));this.node.className=[...set].join(' ')}}
class FakeNode{
  constructor(tag){this.tagName=String(tag).toUpperCase();this.children=[];this.attributes=new Map();this.listeners=new Map();this.textContent='';this.hidden=false;this.disabled=false;this.value='';this.className='';this.parent=null;this.parentElement=null;this.ownerDocument=null;this.style=new FakeStyle();this.classList=new FakeClassList(this);}
  setAttribute(n,v){this.attributes.set(n,String(v));if(n==='value')this.value=String(v)} removeAttribute(n){this.attributes.delete(n)} addEventListener(n,h){if(!this.listeners.has(n))this.listeners.set(n,[]);this.listeners.get(n).push(h)}
  appendChild(c){c.remove();c.parent=this;c.parentElement=this;this.children.push(c);return c} append(...cs){for(const c of cs)this.appendChild(c)}
  insertBefore(c,b){c.remove();c.parent=this;c.parentElement=this;const i=this.children.indexOf(b);if(i<0)this.children.push(c);else this.children.splice(i,0,c)}
  replaceChildren(...cs){for(const c of this.children){c.parent=null;c.parentElement=null}this.children=[];for(const c of cs)this.appendChild(c)}
  remove(){if(!this.parent)return;this.parent.children=this.parent.children.filter(c=>c!==this);this.parent=null;this.parentElement=null}
  fire(n,event={}){for(const h of this.listeners.get(n)??[])h({currentTarget:this,target:event.target??this,preventDefault(){},...event})}
}
class FakeRoot extends FakeNode{constructor(){super('html');this.style=new FakeStyle()}}
class FakeDocument{
  constructor(){this.documentElement=new FakeRoot();this.byId=new Map();for(const id of ['rid-app','rid-actions','rid-connection']){const n=this.createElement(id==='rid-connection'?'div':id==='rid-actions'?'aside':'main');this.byId.set('#'+id,n)}}
  createElement(tag){const n=new FakeNode(tag);n.ownerDocument=this;return n} querySelector(sel){return this.byId.get(sel)??null}
}
const document=new FakeDocument(); globalThis.document=document;

const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'rid-browser-')); const portFile=path.join(tmp,'port'),stopFile=path.join(tmp,'stop'),resultFile=path.join(tmp,'result.json');
const rex=spawn(process.env.REXX_BIN??'rexx',[path.join(root,'tests/rid_web_backend_fixture.rex'),portFile,stopFile,resultFile],{env:process.env,stdio:['ignore','pipe','pipe']});
let stderr='';rex.stderr.on('data',d=>stderr+=d);let stdout='';rex.stdout.on('data',d=>stdout+=d);
for(let i=0;i<700&&!fs.existsSync(portFile);i++)await new Promise(r=>setTimeout(r,20));
assert.ok(fs.existsSync(portFile),`ooRexx backend did not start: ${stdout} ${stderr}`);
const backend=new QueueBackendClient({port:Number(fs.readFileSync(portFile,'utf8').trim()),bridgeToken:'bridge-secret'});
const edge=new QueueFabricWebSocketEdge({backend,inboundQueue:'WIREUI.IN.WEB',host:'127.0.0.1',port:0,path:'/wire-ui',pathToken:'rid-browser-token',pollMs:10}); await edge.start();
const {bootRIDBrowser}=await import(pathToFileURL(path.join(root,'web/rid-browser.js')).href);
const browser=await bootRIDBrowser({gatewayUrl:`ws://127.0.0.1:${edge.port}/wire-ui?token=rid-browser-token`,outboundQueue:'WIREUI.IN.WEB',applicationId:'RID-APP',sessionId:'S1',accessPointId:'WEB'});

for(let i=0;i<400&&!browser.renderer.instances.has('CASE-W');i++)await new Promise(r=>setTimeout(r,10));
assert.ok(browser.renderer.instances.has('CASE-W'),'authoritative case row not rendered');
assert.equal(browser.renderer.slots('CASE-W').providerStatus,'OFFERED');
assert.equal(browser.renderer.slots('CASE-W').nextAction,'PRESENT_MORTGAGE_OFFER_AND_SIGN');

/* Browser filtering is a semantic server action, not a DOM-only filter. */
await browser.controller.filter('product_family','INSURANCE');
for(let i=0;i<300&&(browser.renderer.instances.has('CASE-W')||browser.renderer.slots('case-table').filterRef!=='product_family=INSURANCE');i++)await new Promise(r=>setTimeout(r,10));
assert.equal(browser.renderer.slots('case-table').filterRef,'product_family=INSURANCE');
assert.ok(!browser.renderer.instances.has('CASE-W'),'server-authoritative filter removes out-of-scope row');
await browser.controller.filter('product_family','ALL');
for(let i=0;i<300&&(!browser.renderer.instances.has('CASE-W')||browser.renderer.slots('case-table').filterRef!=='');i++)await new Promise(r=>setTimeout(r,10));
assert.equal(browser.renderer.slots('case-table').filterRef,'');
assert.ok(browser.renderer.instances.has('CASE-W'),'server-authoritative filter restores matching row');

await browser.controller.selectCase('CASE-W');
for(let i=0;i<300&&browser.renderer.slots('case-detail').completionMode!=='SIGNATURE';i++)await new Promise(r=>setTimeout(r,10));
assert.equal(browser.renderer.slots('case-detail').caseId,'CASE-W');
assert.equal(browser.renderer.slots('case-detail').completionMode,'SIGNATURE');
for(let i=0;i<300&&browser.renderer.slots('signing').envelopeId!=='ENV-WEB-1';i++)await new Promise(r=>setTimeout(r,10));
assert.equal(browser.renderer.slots('signing').envelopeId,'ENV-WEB-1');
assert.equal(browser.renderer.slots('signing').storageRef,'STORE:OFFER:WEB');
assert.equal(browser.renderer.slots('signing').durableMediumRef,'DURABLE:OFFER:WEB');
const timeline=browser.renderer.slots('case-timeline'); assert.ok(Number(timeline.windowTotalCount)>=3,'case timeline is server projected');
const providerTimeline=[...browser.renderer.state.entries()].filter(([id,slots])=>String(id).startsWith('RID-TL-PROVIDER-')&&slots.status==='OFFERED');
assert.ok(providerTimeline.length>=1,'browser receives exact provider status timeline');

await browser.controller.prepareSignature('CASE-W',{requirementId:'CUSTOMER-SIGN',authenticationRef:'AUTH:PASSKEY:WEB',consentRef:'CONSENT:WEB'});
for(let i=0;i<300&&!browser.renderer.slots('signing').challengeId;i++)await new Promise(r=>setTimeout(r,10));
const signing=browser.renderer.slots('signing'); assert.equal(signing.challengeId,'RID-SIGN-CHALLENGE-000001');
assert.match(signing.canonicalMessage,/ENV-WEB-1/); assert.equal(signing.signerRef,'CUSTOMER:W');
await browser.controller.submitSignature('CASE-W',{challengeId:signing.challengeId,keyId:'CUSTOMER-W-KEY',signatureHex:'aabb',evidenceRef:'DEVICE:WEBAUTHN:WEB'});
for(let i=0;i<300&&browser.renderer.slots('case-detail').workStatus!=='COMPLETE';i++)await new Promise(r=>setTimeout(r,10));
assert.equal(browser.renderer.slots('case-detail').workStatus,'COMPLETE');
assert.equal(browser.renderer.slots('case-detail').completionEvidenceRef,'SIGNATURE_ENVELOPE:ENV-WEB-1');

await browser.comms.close(); await edge.stop(); fs.writeFileSync(stopFile,'stop');
await new Promise((resolve,reject)=>{rex.once('exit',c=>c===0?resolve():reject(new Error(`backend exit ${c}: ${stdout} ${stderr}`)));setTimeout(()=>reject(new Error(`backend timeout: ${stdout} ${stderr}`)),5000).unref()});
const result=JSON.parse(fs.readFileSync(resultFile,'utf8')); assert.equal(result.workStatus,'COMPLETE'); assert.equal(result.envelopeState,'COMPLETE'); assert.equal(Number(result.challengeUsed),1);
console.log('PASS actual Alchemy browser -> WebSocket edge -> Queue Fabric -> RID Wire UI -> signing -> browser projection');
