import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {pathToFileURL} from 'node:url';

const root=path.resolve(import.meta.dirname,'../..');
const gatewayRoot=process.env.WEB_GATEWAY_ROOT;
if(!gatewayRoot) throw new Error('WEB_GATEWAY_ROOT is required');
const {QueueBackendClient}=await import(pathToFileURL(path.join(gatewayRoot,'node/queue-backend-client.mjs')).href);
const {QueueFabricWebSocketEdge}=await import(pathToFileURL(path.join(gatewayRoot,'node/websocket-edge.mjs')).href);
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'rid-browser-'));
const portFile=path.join(tmp,'backend.port'),stopFile=path.join(tmp,'stop'),resultFile=path.join(tmp,'result.json'),shotFile=path.join(tmp,'rid-browser.png');
const rex=spawn(process.env.REXX_BIN,[path.join(root,'tests/browser/rid_browser_backend_fixture.rex'),portFile,stopFile,resultFile],{env:process.env,stdio:['ignore','pipe','pipe']});
let rexOut='',rexErr='';rex.stdout.on('data',d=>rexOut+=d);rex.stderr.on('data',d=>rexErr+=d);
for(let i=0;i<240&&!fs.existsSync(portFile);i++)await new Promise(r=>setTimeout(r,25));
assert.ok(fs.existsSync(portFile),`ooRexx browser backend did not start\n${rexOut}\n${rexErr}`);
const backend=new QueueBackendClient({port:Number(fs.readFileSync(portFile,'utf8').trim()),bridgeToken:'bridge-secret'});
const edge=new QueueFabricWebSocketEdge({backend,inboundQueue:'WIREUI.IN.WEB',host:'0.0.0.0',port:0,path:'/wire-ui',pathToken:'rid-browser-token',pollMs:10});
await edge.start();

const mime=(file)=>file.endsWith('.js')?'text/javascript; charset=utf-8':file.endsWith('.css')?'text/css; charset=utf-8':file.endsWith('.html')?'text/html; charset=utf-8':'application/octet-stream';
const staticServer=http.createServer((req,res)=>{
  const u=new URL(req.url,'http://rid.invalid'); let file;
  if(u.pathname==='/'||u.pathname==='/intermediary.html') file=path.join(root,'web/intermediary.html');
  else if(u.pathname.startsWith('/rid/')) file=path.join(root,'web',u.pathname.slice('/rid/'.length));
  else if(u.pathname.startsWith('/wire-ui-js/')) file=path.join(root,'web/vendor/alchemy-wire-ui',u.pathname.slice('/wire-ui-js/'.length));
  else {res.writeHead(404);res.end('not found');return;}
  if(!file.startsWith(path.join(root,'web'))||!fs.existsSync(file)){res.writeHead(404);res.end('not found');return;}
  res.writeHead(200,{'content-type':mime(file),'cache-control':'no-store'});res.end(fs.readFileSync(file));
});
await new Promise((resolve,reject)=>{staticServer.once('error',reject);staticServer.listen(0,'0.0.0',resolve)});
const webPort=staticServer.address().port;
const browserHost=process.env.BROWSER_TEST_HOST||Object.values(os.networkInterfaces()).flat().find(x=>x&&x.family==='IPv4'&&!x.internal)?.address;
assert.ok(browserHost,'non-loopback browser test address unavailable');
const url=`http://${browserHost}:${webPort}/?gatewayHost=${browserHost}&gatewayPort=${edge.port}&acceptance=1`;
const chromium=process.env.CHROMIUM_BIN||'/usr/bin/chromium';
const profileDir=path.join(tmp,'chromium-profile');fs.mkdirSync(profileDir,{recursive:true});
const browser=spawn(chromium,['--headless=new','--no-sandbox','--no-proxy-server','--disable-gpu','--disable-dev-shm-usage','--hide-scrollbars','--window-size=1440,1000','--remote-debugging-port=0',`--user-data-dir=${profileDir}`,'about:blank'],{stdio:['ignore','pipe','pipe']});
let browserErr='';browser.stderr.on('data',d=>browserErr+=d);
const activePortFile=path.join(profileDir,'DevToolsActivePort');
for(let i=0;i<240&&!fs.existsSync(activePortFile);i++)await new Promise(r=>setTimeout(r,25));
assert.ok(fs.existsSync(activePortFile),`Chromium DevTools did not start\n${browserErr}`);
const debugPort=Number(fs.readFileSync(activePortFile,'utf8').split(/\r?\n/)[0]);
let targets=[];for(let i=0;i<80;i++){try{targets=await (await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();if(targets.length)break;}catch{}await new Promise(r=>setTimeout(r,25));}
const target=targets.find(t=>t.type==='page')??targets[0];assert.ok(target?.webSocketDebuggerUrl,'Chromium page target absent');
const ws=new WebSocket(target.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true})});
let cdpId=0;const pending=new Map();ws.addEventListener('message',event=>{const msg=JSON.parse(event.data);if(msg.id&&pending.has(msg.id)){const {resolve,reject}=pending.get(msg.id);pending.delete(msg.id);msg.error?reject(new Error(JSON.stringify(msg.error))):resolve(msg.result);}});
const cdp=(method,params={})=>new Promise((resolve,reject)=>{const id=++cdpId;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
const evalValue=async expression=>(await cdp('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true})).result?.value;
await cdp('Page.enable');await cdp('Runtime.enable');await cdp('Page.navigate',{url});
let acceptance='';for(let i=0;i<240;i++){acceptance=await evalValue('document.documentElement.dataset.acceptance || ""');if(acceptance)break;await new Promise(r=>setTimeout(r,50));}
const acceptanceError=await evalValue('document.documentElement.dataset.acceptanceError || document.getElementById("browser-status")?.textContent || ""');
const browserLocation=await evalValue('location.href'); const readyState=await evalValue('document.readyState'); const bodyText=await evalValue('document.body?.innerText?.slice(0,2000) || ""');
assert.equal(acceptance,'PASS',`browser acceptance=${acceptance} location=${browserLocation} ready=${readyState} status=${acceptanceError} body=${bodyText}\n${browserErr}`);
const dom=await evalValue('document.documentElement.outerHTML');
assert.match(dom,/data-provider-status="OFFERED"/,'actual provider status was not observed in browser');
assert.match(dom,/data-selected-case="CASE-W"/,'semantic case selection did not complete');
assert.match(dom,/data-challenge-bound="ENV-BROWSER-1"/,'server-owned signing challenge was not rendered');
assert.match(dom,/data-signature-state="COMPLETE"/,'digital-signature completion was not rendered');
const shot=await cdp('Page.captureScreenshot',{format:'png',captureBeyondViewport:true});fs.writeFileSync(shotFile,Buffer.from(shot.data,'base64'));
for(let i=0;i<200&&!fs.existsSync(resultFile);i++)await new Promise(r=>setTimeout(r,25));
assert.ok(fs.existsSync(resultFile),`ooRexx did not record signed completion\n${rexOut}\n${rexErr}`);
const result=JSON.parse(fs.readFileSync(resultFile,'utf8'));
assert.equal(result.providerStatus,'OFFERED');assert.equal(result.workStatus,'COMPLETE');assert.equal(result.envelopeState,'COMPLETE');assert.equal(result.signatures,1);assert.equal(result.completionEvidenceRef,'SIGNATURE_ENVELOPE:ENV-BROWSER-1');
const packagedShot=path.join(root,'browser_acceptance.png');fs.copyFileSync(shotFile,packagedShot);
try{await cdp('Browser.close')}catch{}ws.close();
await new Promise(r=>setTimeout(r,100));if(browser.exitCode==null)browser.kill('SIGTERM');
await edge.stop();await new Promise(r=>staticServer.close(r));fs.writeFileSync(stopFile,'stop');
await new Promise((resolve,reject)=>{const timer=setTimeout(()=>{rex.kill('SIGKILL');reject(new Error(`ooRexx fixture stop timeout\n${rexOut}\n${rexErr}`))},5000);rex.once('exit',c=>{clearTimeout(timer);c===0?resolve():reject(new Error(`ooRexx fixture exit ${c}\n${rexOut}\n${rexErr}`))})});
console.log('PASS Chromium -> WebSocket edge -> Queue Fabric -> Wire UI Server -> RID signing -> retained work completion');
