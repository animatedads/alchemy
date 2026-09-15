import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { MerchantWorkspaceContextEcho } from '../web/merchant-workspace-context.js';

const HERE=path.dirname(fileURLToPath(import.meta.url));
const ROOT=path.resolve(HERE,'..');
const gatewayRoot=process.env.WIRE_UI_GATEWAY_ROOT;
const jsRoot=process.env.ALCHEMY_WIRE_UI_JS_ROOT;
const rexx=process.env.FBM_REXX;
if(!gatewayRoot||!jsRoot||!rexx) throw new Error('WIRE_UI_GATEWAY_ROOT, ALCHEMY_WIRE_UI_JS_ROOT and FBM_REXX are required');

const {QueueBackendClient}=await import(pathToFileURL(path.join(gatewayRoot,'node/queue-backend-client.mjs')).href);
const {QueueFabricWebSocketEdge}=await import(pathToFileURL(path.join(gatewayRoot,'node/websocket-edge.mjs')).href);
const api=await import(pathToFileURL(path.join(jsRoot,'src/index.js')).href);
const {QueueFabricGatewayTransport,Comms,DefinitionRegistry,BrowserRenderer,WireUIRuntime,RenderProfileController,WireUIJourneyController,ObservationPlan,MaterialController,MessageKind}=api;

class FakeNode {
  constructor(tag){this.tagName=String(tag).toUpperCase();this.children=[];this.attributes=new Map();this.listeners=new Map();this.textContent='';this.hidden=false;this.disabled=false;this.value='';this.className='';this.parent=null;this.parentElement=null;this.ownerDocument=null;}
  setAttribute(n,v){this.attributes.set(n,String(v)); if(n==='value')this.value=String(v);}
  removeAttribute(n){this.attributes.delete(n);}
  addEventListener(n,h){this.listeners.set(n,h);}
  appendChild(c){c.remove();c.parent=this;c.parentElement=this;this.children.push(c);}
  insertBefore(c,b){c.remove();c.parent=this;c.parentElement=this;const i=this.children.indexOf(b);if(i<0)this.children.push(c);else this.children.splice(i,0,c);}
  replaceChildren(...cs){for(const c of this.children){c.parent=null;c.parentElement=null;}this.children=[];for(const c of cs)this.appendChild(c);}
  remove(){if(!this.parent)return;this.parent.children=this.parent.children.filter(c=>c!==this);this.parent=null;this.parentElement=null;}
  fire(n){this.listeners.get(n)?.({currentTarget:this,target:this,preventDefault(){}});}
}
class FakeStyle {constructor(){this.values=new Map();}setProperty(n,v){this.values.set(n,String(v));}removeProperty(n){this.values.delete(n);}getPropertyValue(n){return this.values.get(n)??'';}}
class FakeRoot {constructor(){this.style=new FakeStyle();this.attributes=new Map();}setAttribute(n,v){this.attributes.set(n,String(v));}}
class FakeDocument {constructor(){this.documentElement=new FakeRoot();}createElement(tag){const n=new FakeNode(tag);n.ownerDocument=this;return n;}}

const wait=async(fn,ms=8000)=>{const until=Date.now()+ms;while(Date.now()<until){const v=fn();if(v)return v;await new Promise(r=>setTimeout(r,15));}throw new Error('timeout waiting for condition');};
const allText=(node)=>[node?.textContent??'',...(node?.children??[]).map(allText)].join(' ');
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'fbm-wire-browser-'));
const portFile=path.join(tmp,'port'); const stopFile=path.join(tmp,'stop'); const resultFile=path.join(tmp,'result.json');
const pkg=path.join(ROOT,'semantic/federationbank_merchant_operations_v0.6.json');
const child=spawn(rexx,[path.join(HERE,'merchant_browser_backend_fixture.rex'),portFile,stopFile,resultFile,pkg],{cwd:ROOT,env:{...process.env},stdio:['ignore','pipe','pipe']});
let stderr=''; child.stderr.on('data',d=>stderr+=d); let stdout=''; child.stdout.on('data',d=>stdout+=d);
try {
  await wait(()=>fs.existsSync(portFile),8000);
  const backend=new QueueBackendClient({port:Number(fs.readFileSync(portFile,'utf8').trim()),bridgeToken:'bridge-secret'});
  const edge=new QueueFabricWebSocketEdge({backend,inboundQueue:'WIREUI.IN.WEB',host:'127.0.0.1',port:0,path:'/wire-ui',pathToken:'browser-token',pollMs:5});
  await edge.start();
  try {
    const ownership={applicationId:'FBM-LIVE',sessionId:'S-LIVE',accessPointId:'WEB'};
    const transport=new QueueFabricGatewayTransport({url:`ws://127.0.0.1:${edge.port}/wire-ui?token=browser-token`,outboundQueue:'WIREUI.IN.WEB',ownership,putResultMode:'required'});
    const comms=new Comms({transport,source:'FBM.BROWSER.TEST',destination:'WIREUI.IN.WEB'});
    let capturedAction=null;
    const baseSend=comms.send.bind(comms);
    comms.send=async(kind,payload,options)=>{if(kind===MessageKind.UI_ACTION) capturedAction=structuredClone(payload);return baseSend(kind,payload,options);};
    const echo=new MerchantWorkspaceContextEcho({comms,MessageKind}).install();
    const definitions=new DefinitionRegistry(); const document=new FakeDocument(); const mount=document.createElement('main');
    const renderer=new BrowserRenderer({definitions,mount,document}); const material=new MaterialController({comms,document});
    const profile=new RenderProfileController({comms,definitions,renderer,siteId:'FEDERATIONBANK_MERCHANT'});
    const runtime=new WireUIRuntime({comms,definitions,renderer,serverSemantic:true,renderProfile:profile,ownership});
    new WireUIJourneyController({comms,runtime}); new ObservationPlan({comms});
    await comms.connect(profile.helloPayload({applicationId:ownership.applicationId,sessionId:ownership.sessionId,accessPointId:'WEB'}));
    await wait(()=>renderer.instances.has('ROOT-A::OPEN')&&renderer.instances.has('ROOT-B')&&renderer.instances.has('workspace-context'));
    assert.ok(renderer.instances.has('ROOT-A'),'semantic ROOT-A row rendered as its own child instance');
    assert.ok(renderer.instances.has('ROOT-C'),'0/1/N collection materialises independent semantic rows');
    const contextInstance=renderer.instances.get('workspace-context');
    assert.equal(contextInstance.root.hidden,true,'workspace command context is non-visual');
    assert.equal(echo.context.workspaceRef,'FBM.BOOKS');
    assert.deepEqual(echo.context.selectedIds,[]);
    const open=renderer.instances.get('ROOT-A::OPEN');
    assert.equal(open.root.tagName,'BUTTON');
    assert.match(allText(open.root),/Open book/i);
    open.root.fire('click');
    await wait(()=>fs.existsSync(resultFile));
    await wait(()=>allText(renderer.instances.get('book-detail')?.root).includes('ROOT-A'));
    assert.equal(capturedAction.action,'BOOK.OPEN');
    assert.equal(capturedAction.elementInstance,'ROOT-A::OPEN');
    assert.equal('rootTradeId' in (capturedAction.detail??{}),false,'browser does not supply Merchant book identity');
    assert.equal(capturedAction.detail.workspaceContext.workspaceRef,'FBM.BOOKS');
    assert.deepEqual(capturedAction.detail.workspaceContext.selectedIds,[],'action echoes pre-selection server context');
    const serverResult=JSON.parse(fs.readFileSync(resultFile,'utf8'));
    assert.equal(serverResult.selectedRootTradeId,'ROOT-A','server resolves row identity from server-issued action instance');
    assert.deepEqual(serverResult.workspaceContext.selectedIds,['ROOT-A']);
    assert.ok(serverResult.workspaceContext.selectionRevision>capturedAction.detail.workspaceContext.selectionRevision);
    await comms.close();
  } finally { await edge.stop(); }
} catch(error) {
  throw new Error(`${error.message}\nooRexx stdout:\n${stdout.slice(-4000)}\nooRexx stderr:\n${stderr.slice(-4000)}`);
} finally {
  fs.writeFileSync(stopFile,'stop');
  await new Promise(resolve=>{const t=setTimeout(()=>{child.kill('SIGTERM');resolve();},3000);child.once('exit',()=>{clearTimeout(t);resolve();});});
}
console.log('PASS Merchant semantic rows cross real Queue Fabric Web Gateway into BrowserRenderer and BOOK.OPEN returns with current workspace context');
