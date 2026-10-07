import test from 'node:test'; import assert from 'node:assert/strict';
import { QueueFabricWebSocketEdge } from '../node/websocket-edge.mjs';
class Backend { constructor(){this.put=[];this.claimed=false;this.ack=[];} async request(op,f={}){if(op==='PING')return 'OK'; if(op==='PUT'){this.put.push(f);return {packageId:'p-in'};} if(op==='CLAIM'){if(this.claimed){const e=new Error('QUEUE_EMPTY');e.code='QUEUE_EMPTY';throw e;}this.claimed=true;return {claimToken:'private-token',package:{packageId:'p-out',sequence:9,payload:{type:'UI_VIEW_PATCH'},correlationId:'',requestedQueue:'OUT',currentQueue:'OUT',createdAt:new Date().toISOString()}};} if(['ACK','NACK','RELEASE'].includes(op)){this.ack.push([op,f]);return 'OK';}throw new Error(op);} }
const wait=(ms)=>new Promise(r=>setTimeout(r,ms));
test('edge hides claim token and preserves PUT result correlation',async()=>{const backend=new Backend();const edge=new QueueFabricWebSocketEdge({backend,inboundQueue:'IN',host:'127.0.0.1',port:0,path:'/wire-ui',pathToken:'t',pollMs:5});await edge.start();const ws=new WebSocket(`ws://127.0.0.1:${edge.port}/wire-ui?token=t`);const frames=[];ws.addEventListener('message',e=>frames.push(JSON.parse(e.data)));await new Promise((r,j)=>{ws.addEventListener('open',r,{once:true});ws.addEventListener('error',j,{once:true});});for(let i=0;i<50&&!frames.find(f=>f.type==='QUEUE_DELIVERY');i++)await wait(5);const d=frames.find(f=>f.type==='QUEUE_DELIVERY');assert.ok(d);assert.equal('claimToken' in d,false);assert.equal(JSON.stringify(d).includes('private-token'),false);ws.send(JSON.stringify({type:'QUEUE_DELIVERY_ACK',deliveryId:d.deliveryId,messageId:d.package.packageId}));ws.send(JSON.stringify({type:'QUEUE_PUT',clientPutId:'c1',queue:'IN',payload:{type:'UI_ACTION'}}));for(let i=0;i<50&&!frames.find(f=>f.type==='QUEUE_PUT_RESULT');i++)await wait(5);assert.equal(frames.find(f=>f.type==='QUEUE_PUT_RESULT').clientPutId,'c1');ws.close();await wait(20);await edge.stop();});
test('edge rejects browser-selected queue outside binding',async()=>{const backend=new Backend();backend.claimed=true;const edge=new QueueFabricWebSocketEdge({backend,inboundQueue:'IN',host:'127.0.0.1',port:0,path:'/wire-ui',pathToken:'t',pollMs:5});await edge.start();const ws=new WebSocket(`ws://127.0.0.1:${edge.port}/wire-ui?token=t`);const frames=[];ws.addEventListener('message',e=>frames.push(JSON.parse(e.data)));await new Promise(r=>ws.addEventListener('open',r,{once:true}));ws.send(JSON.stringify({type:'QUEUE_PUT',clientPutId:'bad',queue:'OTHER',payload:{type:'UI_ACTION'}}));for(let i=0;i<50&&!frames.length;i++)await wait(5);assert.equal(frames[0].accepted,false);assert.equal(frames[0].code,'QUEUE_NOT_BOUND');ws.close();await wait(20);await edge.stop();});

test('bootstrap endpoint exposes browser-safe session binding and no private queue state', async()=>{
  const backend=new Backend(); backend.claimed=true;
  const edge=new QueueFabricWebSocketEdge({
    backend,
    inboundQueue:'WIREUI.IN.AP-1',
    host:'127.0.0.1', port:0, path:'/wire-ui', pathToken:'session-token', pollMs:5,
    bootstrap:{
      moduleUrl:'/alchemy-wire-ui-v0.4-dev3/src/index.js',
      siteId:'FLYLO',
      ownership:{applicationId:'FLYLO-APP',sessionId:'SESSION-1',accessPointId:'AP-1'}
    }
  });
  await edge.start();
  const denied=await fetch(`http://127.0.0.1:${edge.port}/wire-ui/bootstrap?token=wrong`);
  assert.equal(denied.status,404);
  const response=await fetch(`http://127.0.0.1:${edge.port}/wire-ui/bootstrap?token=session-token`);
  assert.equal(response.status,200);
  assert.match(response.headers.get('cache-control'),/no-store/);
  const config=await response.json();
  assert.equal(config.outboundQueue,'WIREUI.IN.AP-1');
  assert.equal(config.ownership.applicationId,'FLYLO-APP');
  assert.equal(config.ownership.sessionId,'SESSION-1');
  assert.equal(config.ownership.accessPointId,'AP-1');
  assert.equal(config.siteId,'FLYLO');
  assert.equal(config.gatewayUrl,`ws://127.0.0.1:${edge.port}/wire-ui?token=session-token`);
  const text=JSON.stringify(config);
  assert.equal(text.includes('claimToken'),false);
  assert.equal(text.includes('bridgeToken'),false);
  assert.equal(text.includes('principal'),false);
  assert.equal(text.includes('OUT'),false);
  await edge.stop();
});
