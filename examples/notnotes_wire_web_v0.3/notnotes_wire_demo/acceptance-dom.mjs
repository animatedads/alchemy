/* One-shot, isolated end-to-end live Wire gateway test against real MiniNotesApp.
 * The host is ooRexx; this file is only an integration test driver. */
import fs from 'node:fs'; import os from 'node:os'; import path from 'node:path';
import {spawn,spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
import {QueueBackendClient} from '../oorexx_queue_fabric_web_gateway_v0.2/node/queue-backend-client.mjs';
import {QueueFabricWebSocketEdge} from '../oorexx_queue_fabric_web_gateway_v0.2/node/websocket-edge.mjs';
import {QueueFabricGatewayTransport,Comms,DefinitionRegistry,BrowserRenderer,WireUIRuntime,RenderProfileController,MemoryDefinitionCache} from '../alchemy_wire_ui_js_v0.4-dev6/src/index.js';
const here=import.meta.dirname, root=path.resolve(here,'..');
const state=fs.mkdtempSync(path.join(os.tmpdir(),'notnotes-live-'));
const files={port:path.join(state,'port'),stop:path.join(state,'stop'),receipt:path.join(state,'receipt.json'),db:path.join(state,'db')};
fs.mkdirSync(files.db);const rexHome=process.env.OOREXX_HOME||'/usr/local';
const srcs=['src','vendor/notnotes','vendor/intention','vendor/nosql','vendor/cliui/rexx','vendor/pdf/src','vendor/spreadsheet','wire_ui_builder_v0.6/examples/notnotes','wire_ui_server_v0.17/src','oorexx_queue_fabric_web_gateway_v0.2/src','oorexx_queue_fabric_v0.9-dev6/src','alchemy_objects_v0.8/src','oorexx_crypto_v0.8.3/src'].map(x=>path.join(root,x));
const env={...process.env,PATH:rexHome+'/bin:'+process.env.PATH,LD_LIBRARY_PATH:rexHome+'/lib:'+rexHome+'/lib64',REXX_PATH:[...srcs,rexHome+'/bin'].join(':')};
const rex=spawn(rexHome+'/bin/rexx',[path.join(here,'NotNotesWireBackend.rex'),files.port,files.stop,files.receipt,files.db],{cwd:root,env,stdio:['ignore','pipe','pipe']});
let rexOut='',rexErr='';rex.stdout.on('data',b=>rexOut+=String(b));rex.stderr.on('data',b=>rexErr+=String(b));

// DOM-conformance fixture from the Queue Fabric browser-roundtrip tests.
class FakeNode {
  constructor(tag){this.tagName=String(tag).toUpperCase();this.children=[];this.attributes=new Map();this.listeners=new Map();this.textContent='';this.hidden=false;this.disabled=false;this.value='';this.className='';this.parent=null;this.ownerDocument=null;}
  setAttribute(n,v){this.attributes.set(n,String(v));if(n==='value')this.value=String(v);} removeAttribute(n){this.attributes.delete(n);} addEventListener(n,h){this.listeners.set(n,h);}
  appendChild(c){c.remove();c.parent=this;this.children.push(c);} insertBefore(c,b){c.remove();c.parent=this;const i=this.children.indexOf(b);if(i<0)this.children.push(c);else this.children.splice(i,0,c);}
  replaceChildren(...cs){for(const c of this.children)c.parent=null;this.children=[];for(const c of cs)this.appendChild(c);}
  remove(){if(!this.parent)return;this.parent.children=this.parent.children.filter(c=>c!==this);this.parent=null;}
  fire(n,target=this){this.listeners.get(n)?.({currentTarget:this,target,preventDefault(){}});}
}
class FakeDocument { createElement(tag){const n=new FakeNode(tag);n.ownerDocument=this;return n;} }

const sleep=n=>new Promise(r=>setTimeout(r,n));
async function wait(fn,what,max=10000){for(let i=0;i<max/40;i++){if(fn())return;await sleep(40);}throw Error('Timeout '+what+' Rexx '+rexOut.slice(-600)+' '+rexErr.slice(-600));}
let edge,comms,renderer,runtime,received=[];
try{
 await wait(()=>fs.existsSync(files.port),'ooRexx backend');
 const port=Number(fs.readFileSync(files.port,'utf8').trim());
 edge=new QueueFabricWebSocketEdge({backend:new QueueBackendClient({port,bridgeToken:'notnotes-dev-bridge-token'}),inboundQueue:'WIREUI.IN.AP1',host:'127.0.0.1',port:0,path:'/wire-ui',pollMs:10});await edge.start();
 const ownership={applicationId:'NOTNOTES',sessionId:'S1',accessPointId:'AP1'};
 const transport=new QueueFabricGatewayTransport({url:`ws://127.0.0.1:${edge.port}/wire-ui`,outboundQueue:'WIREUI.IN.AP1',ownership,WebSocketImpl:WebSocket,putResultMode:'required'});
 comms=new Comms({transport,source:'NOTNOTES.E2E',destination:'WIREUI.IN.AP1'});
 const definitions=new DefinitionRegistry(); const document=new FakeDocument(); const mount=document.createElement('main');renderer=new BrowserRenderer({definitions,mount,document});
 const profile=new RenderProfileController({comms,definitions,definitionCache:new MemoryDefinitionCache(),renderer,siteId:'NOTNOTES_WEB_WIRE'});
 runtime=new WireUIRuntime({comms,definitions,renderer,renderProfile:profile,serverSemantic:true,ownership});
 const origSend=comms.send.bind(comms);comms.send=async(...args)=>{console.log('SEND',args[0]);return origSend(...args);};
 comms.onAny((payload,e)=>received.push({kind:e.kind,code:payload.code??null}));
 comms.onState(event=>{if(event.type==='inbound-handler-error')console.log('ERROR INBOUND',event.error?.stack??String(event.error));});
 await comms.connect(profile.helloPayload({accessPointId:'AP1'}));
 await wait(()=>renderer.instances.has('approve'),'Wire definitions and snapshot');
 const state=()=>({docs:renderer.instances.get('documents').root.children.length,
  selected:renderer.instances.get('selection').root.textContent,
  status:renderer.instances.get('status').root.textContent,
  revision:runtime.revision,auth:runtime.actionsBlockedByAuthority,manifest:runtime.manifestId});
 console.log('DOM SNAPSHOT',JSON.stringify(state()));
 assert.equal(state().docs,5,'five actual DOM collection children');
 assert.equal(state().status,'PENDING APPROVAL');
 assert.equal(runtime.actionsBlockedByAuthority,false,'definition authority must allow actions');
 // Exercise a real DOM click on the collection-item, through Wire UI_ACTION
 const list=renderer.instances.get('documents').root;
 const item=list.children.find(c=>c.__wireActionDetail?.key==='SEC-2001');
 if(!item)throw Error('Expected SEC-2001 action row missing');
 list.fire('click',item);
 await wait(()=>state().selected.includes('SEC-2001') && state().revision>=1,'document selection DOM click',7000);
 console.log('SELECTED VIA DOM',JSON.stringify(state()));
 const revert=list.children.find(c=>c.__wireActionDetail?.key==='PR-1002');
 list.fire('click',revert);
 await wait(()=>state().selected.includes('PR-1002') && state().revision>=2,'document reselection DOM click',7000);
 renderer.instances.get('approve').root.fire('click');
 await wait(()=>state().status==='APPROVED' && runtime.revision>=3,'server-side approval DOM patch',7000);
 assert.ok(runtime.revision>=3,'DOM actions must advance authoritative revision');
 console.log('PASS DOM renderer approval',JSON.stringify(state()));
 const getForm=(id)=>renderer.instances.get(id);
 const fill=(form,name,value)=>{ const node=[...form.nodes.values()].find(n=>n.attributes?.get('name')===name); if(!node)throw Error(`Missing ${name} on form`); node.value=String(value); };
 const create=getForm('create');
 assert.ok(create,'Wire create form must be present');
 assert.equal(create.nodes.get('submit').textContent,'Create document','server-authored form action label');
 fill(create,'type','Purchase Request');fill(create,'title','QA Wire new laptop');fill(create,'amount','1350');fill(create,'risk','LOW');fill(create,'dependsOn','SUP-001');
 create.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('CREATED'),'create action via Wire form',9000);
 const newSelection=state().selected; assert.ok(newSelection.includes('PR-'),'created key selected');
 await wait(()=>state().docs===6 && runtime.revision>=4,'created record visible in authoritative collection');
 console.log('PASS CREATE via Wire DOM',JSON.stringify({newSelection,revision:runtime.revision}));
 const edit=getForm('edit');fill(edit,'title','QA Wire edited laptop');fill(edit,'amount','1550');fill(edit,'risk','MEDIUM');
 edit.root.fire('submit');
 await wait(()=>renderer.instances.get('title').root.textContent==='QA Wire edited laptop' && runtime.revision>=5,'edit action via Wire form',9000);
 assert.ok(['DRAFT','PENDING APPROVAL'].includes(renderer.instances.get('status').root.textContent));
 console.log('PASS EDIT via Wire DOM',JSON.stringify({title:renderer.instances.get('title').root.textContent,revision:runtime.revision}));
 const intention=getForm('intention');fill(intention,'request','show views');intention.root.fire('submit');
 await wait(()=>renderer.instances.get('intentionResult').root.textContent.includes('Intention status:'),'Intention Service via Wire',9000);
 console.log('PASS Intention read',renderer.instances.get('intentionResult').root.textContent);
 await wait(()=>runtime.revision>=6,'intention read patches',9000);
 fill(intention,'request','from notnotes set title to Intent-adjusted on PR-1003');intention.root.fire('submit');
 await wait(()=>renderer.instances.get('intentionResult').root.textContent.includes('CONFIRM'),'intention write asks explicit confirmation',9000);
 console.log('PASS Intention WRITE confirmation requested',renderer.instances.get('intentionResult').root.textContent);
 await wait(()=>runtime.revision>=7,'intention confirm patches',9000);
 fill(intention,'request','yes');intention.root.fire('submit');
 await wait(()=>runtime.revision>=8,'confirmed intention patch',9000);
 console.log('INTENT POST-CONFIRM',JSON.stringify({title:renderer.instances.get('title').root.textContent,feedback:renderer.instances.get('feedback').root.textContent,parsed:renderer.instances.get('intentionResult').root.textContent}));
 assert.equal(renderer.instances.get('title').root.textContent,'INTENT-ADJUSTED');
 console.log('PASS Intention WRITE dispatched',renderer.instances.get('intentionResult').root.textContent);
 // An invalid domain action must not be a silent, pressable-looking button.
 const approvedRow=[...list.children].find(c=>c.__wireActionDetail?.key==='PR-1002');
 list.fire('click',approvedRow);
 await wait(()=>state().selected.includes('PR-1002') && runtime.revision>=9,'return to approved document',9000);
 getForm('approve').root.fire('click');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('REFUSED NOT_PENDING'),'explicit refusal visible',9000);
 assert.equal(state().status,'APPROVED','refused approval must not mutate document');
 console.log('PASS REFUSAL visible over Wire',renderer.instances.get('feedback').root.textContent);
 const before=state().docs;
 fill(create,'title',''); create.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('REFUSED TITLE_REQUIRED'),'invalid create visible',9000);
 assert.equal(state().docs,before);
 console.log('PASS VALIDATION error visible over Wire',renderer.instances.get('feedback').root.textContent);


 // Format/schema authoring is an authoritative MiniNotesApp operation, not JS state.
 const format=getForm('format'); assert.ok(format,'server defined format designer');
 fill(format,'format','Purchase Checklist');
 fill(format,'fields','OWNER|Owner|TEXT;RELATED|Related Purchase|DOCUMENT_REFERENCE|Purchase Request|MANY;COST|Cost|MONEY');
 format.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('FORMAT_CREATED'),'saved typed format',9000);
 assert.ok(renderer.instances.get('catalogue').root.textContent.includes('Purchase Checklist'));
 console.log('PASS FORMAT DESIGN via Wire',renderer.instances.get('catalogue').root.textContent);
 await wait(()=>runtime.revision>=12,'format update patch',9000);
 const complete=getForm('userDoc');fill(complete,'format','Purchase Checklist');
 fill(complete,'values','OWNER=Casey;RELATED=PR-1001;COST=150');
 complete.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('DOCUMENT_CREATED'),'custom document complete',9000);
 await wait(()=>state().docs===7,'custom document in Wire collection',9000);
 const customSelection=state().selected;assert.ok(customSelection.includes('Selected: ') && !customSelection.includes('PR-1002'),'created stable custom document key');
 console.log('PASS CUSTOM DOCUMENT via Wire',customSelection);
 const typed=getForm('typed');fill(typed,'field','COST');fill(typed,'value','175');typed.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('NOTNOTES.SET_FIELD : UPDATED'),'typed field changed',9000);
 const link=getForm('link');fill(link,'field','RELATED');fill(link,'target','PR-1002');link.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('NOTNOTES.LINK_DOCUMENT : LINKED'),'reference link',9000);
 const unlink=getForm('unlink');fill(unlink,'field','RELATED');fill(unlink,'target','PR-1001');unlink.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('NOTNOTES.UNLINK_DOCUMENT : UNLINKED'),'reference unlink',9000);
 console.log('PASS TYPED FIELD + LINK/UNLINK through Wire');
 const reportDesign=getForm('reportDesign');fill(reportDesign,'report','Checklist totals');fill(reportDesign,'sourceForm','Purchase Checklist');fill(reportDesign,'columns','Key=KEY;Owner=OWNER;Cost=COST');
 reportDesign.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('REPORT_CREATED'),'saved report design',9000);
 await wait(()=>renderer.instances.get('catalogue').root.textContent.includes('Checklist totals'),'saved report catalogue',9000);
 const reportRun=getForm('reportRun');fill(reportRun,'report','Checklist totals');reportRun.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('REPORTED'),'saved report execution',9000);
 assert.ok(renderer.instances.get('reportOutput').root.textContent.includes('Casey'),'report contains real document data');
 console.log('PASS REPORT DESIGN/RUN through Wire',renderer.instances.get('reportOutput').root.textContent);
 fill(typed,'field','COST');fill(typed,'value','not-a-number');typed.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('FIELD_UPDATE_REJECTED'),'invalid numeric typed field refusal',9000);
 console.log('PASS TYPED FIELD invalid input refused');
 // Negative admission cases must fail closed without changing format/report state.
 fill(format,'format','Purchase Checklist');format.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('REFUSED FORMAT_EXISTS'),'duplicate format refused',9000);
 fill(reportRun,'report','Absent report');reportRun.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('REFUSED REPORT_NOT_FOUND'),'unknown report refused',9000);
 fill(complete,'format','Purchase Checklist');fill(complete,'values','OWNER=Invalid;RELATED=NOT-A-DOCUMENT;COST=20');
 complete.root.fire('submit');
 await wait(()=>renderer.instances.get('feedback').root.textContent.includes('REFUSED DOCUMENT_VALIDATION_FAILED'),'unknown reference refused',9000);
 assert.equal(state().docs,7,'no phantom document after invalid reference');
 console.log('PASS duplicate format, absent report and unknown reference refusals');
 fs.writeFileSync(path.join(here,'wire-dom-test-result.json'),JSON.stringify({result:'PASS',kind:'BrowserRenderer FakeDocument DOM conformance',...state(),received},null,2));
}catch(e){console.error('FAIL',e.stack,'REXX',rexOut,rexErr,'received',received);fs.writeFileSync(path.join(here,'wire-dom-test-result.json'),JSON.stringify({status:'FAIL',error:e.stack,rexx:rexOut+rexErr,received},null,2));process.exitCode=1;}
finally {try{await comms?.close()}catch{};try{await edge?.stop()}catch{};fs.writeFileSync(files.stop,'stop\n');await sleep(400);if(rex.exitCode==null)rex.kill('SIGTERM');fs.writeFileSync(path.join(here,'backend-last.log'),rexOut+rexErr);if(fs.existsSync(files.receipt))fs.copyFileSync(files.receipt,path.join(here,'backend-receipt.json'));
 if(!process.exitCode){
   const verification=spawnSync(rexHome+'/bin/rexx',[path.join(here,'verify-persistence.rex'),files.db],{cwd:root,env,encoding:'utf8',timeout:10000});
   console.log(verification.stdout.trim());
   if(verification.status!==0){console.error('FAIL persistence',verification.status,verification.stderr);process.exitCode=1;}
 }
}
