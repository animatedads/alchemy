/* One-shot, isolated end-to-end live Wire gateway test against real MiniNotesApp.
 * The host is ooRexx; this file is only an integration test driver. */
import fs from 'node:fs'; import os from 'node:os'; import path from 'node:path';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import {QueueBackendClient} from '../oorexx_queue_fabric_web_gateway_v0.2/node/queue-backend-client.mjs';
import {QueueFabricWebSocketEdge} from '../oorexx_queue_fabric_web_gateway_v0.2/node/websocket-edge.mjs';
import {QueueFabricGatewayTransport,Comms,DefinitionRegistry,MemoryRenderer,WireUIRuntime,RenderProfileController,MemoryDefinitionCache} from '../alchemy_wire_ui_js_v0.4-dev6/src/index.js';
const here=import.meta.dirname, root=path.resolve(here,'..');
const state=fs.mkdtempSync(path.join(os.tmpdir(),'notnotes-live-'));
const files={port:path.join(state,'port'),stop:path.join(state,'stop'),receipt:path.join(state,'receipt.json'),db:path.join(state,'db')};
fs.mkdirSync(files.db);const rexHome=process.env.OOREXX_HOME||'/usr/local';
const srcs=['src','vendor/notnotes','vendor/intention','vendor/nosql','vendor/cliui/rexx','vendor/pdf/src','vendor/spreadsheet','wire_ui_builder_v0.6/examples/notnotes','wire_ui_server_v0.17/src','oorexx_queue_fabric_web_gateway_v0.2/src','oorexx_queue_fabric_v0.9-dev6/src','alchemy_objects_v0.8/src','oorexx_crypto_v0.8.3/src'].map(x=>path.join(root,x));
const env={...process.env,PATH:rexHome+'/bin:'+process.env.PATH,LD_LIBRARY_PATH:rexHome+'/lib:'+rexHome+'/lib64',REXX_PATH:[...srcs,rexHome+'/bin'].join(':')};
const rex=spawn(rexHome+'/bin/rexx',[path.join(here,'NotNotesWireBackend.rex'),files.port,files.stop,files.receipt,files.db],{cwd:root,env,stdio:['ignore','pipe','pipe']});
let rexOut='',rexErr='';rex.stdout.on('data',b=>rexOut+=String(b));rex.stderr.on('data',b=>rexErr+=String(b));
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
 const definitions=new DefinitionRegistry();renderer=new MemoryRenderer({definitions});
 const profile=new RenderProfileController({comms,definitions,definitionCache:new MemoryDefinitionCache(),renderer,siteId:'NOTNOTES_WEB_WIRE'});
 runtime=new WireUIRuntime({comms,definitions,renderer,renderProfile:profile,serverSemantic:true,ownership});
 const origSend=comms.send.bind(comms);comms.send=async(...args)=>{console.log('SEND',args[0]);return origSend(...args);};
 comms.onAny((payload,e)=>received.push({kind:e.kind,code:payload.code??null}));
 comms.onState(event=>{if(event.type==='inbound-handler-error')console.log('ERROR INBOUND',event.error?.stack??String(event.error));});
 await comms.connect(profile.helloPayload({accessPointId:'AP1'}));
 await wait(()=>renderer.getInstance('approve'),'Wire definitions and snapshot');
 console.log('SNAPSHOT',JSON.stringify({docs:renderer.getInstance('documents').slots.items.length,selected:renderer.getInstance('selection').slots.value,status:renderer.getInstance('status').slots.value,revision:runtime.revision,auth:runtime.actionsBlockedByAuthority,manifest:runtime.manifestId}));
 assert.equal(renderer.getInstance('status').slots.value,'PENDING APPROVAL');
 assert.equal(runtime.actionsBlockedByAuthority,false,'definition authority must allow actions');
 renderer.emitAction('approve','NOTNOTES.APPROVE',{});
 await wait(()=>renderer.getInstance('status')?.slots?.value==='APPROVED' && runtime.revision>=1,'server-side approval patch',7000);
 console.log('PASS approval status',renderer.getInstance('status').slots.value,'revision',runtime.revision);
 fs.writeFileSync(path.join(here,'wire-test-result.json'),JSON.stringify({status:'PASS',root:renderer.rootInstanceId,docs:renderer.getInstance('documents').slots.items.length,selected:renderer.getInstance('selection').slots.value,approvalStatus:renderer.getInstance('status').slots.value,revision:runtime.revision,manifestId:runtime.manifestId,received},null,2));
}catch(e){console.error('FAIL',e.stack,'REXX',rexOut,rexErr,'received',received);fs.writeFileSync(path.join(here,'wire-test-result.json'),JSON.stringify({status:'FAIL',error:e.stack,rexx:rexOut+rexErr,received},null,2));process.exitCode=1;}
finally {try{await comms?.close()}catch{};try{await edge?.stop()}catch{};fs.writeFileSync(files.stop,'stop\n');await sleep(400);if(rex.exitCode==null)rex.kill('SIGTERM');fs.writeFileSync(path.join(here,'backend-last.log'),rexOut+rexErr);if(fs.existsSync(files.receipt))fs.copyFileSync(files.receipt,path.join(here,'backend-receipt.json'));}
