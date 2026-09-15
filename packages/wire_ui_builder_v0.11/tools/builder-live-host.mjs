#!/usr/bin/env node
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const HERE=path.dirname(fileURLToPath(import.meta.url));
const BUILDER_ROOT=path.resolve(process.env.WUIB_BUILDER_ROOT??path.join(HERE,'..'));
const GATEWAY_ROOT=needPath('WUIB_GATEWAY_ROOT');
const JS_ROOT=needPath('WUIB_JS_ROOT');
const REXX=process.env.WUIB_REXX||process.env.REXX||'rexx';
const args=parseArgs(process.argv.slice(2));
const bridgeToken=crypto.randomBytes(32).toString('hex');
const pathToken=crypto.randomBytes(24).toString('hex');
let backend=null, gateway=null, web=null, stopping=false, gatewayInfo=null, backendInfo=null;

function needPath(name){
  const value=process.env[name];
  if(!value) throw new Error(`${name} is required; use run_builder_studio.sh so exact runtime dependencies are resolved for you`);
  return path.resolve(value);
}
function parseArgs(argv){
  const out={host:'127.0.0.1',port:8765,open:false,json:false};
  for(let i=0;i<argv.length;i++){
    const a=argv[i];
    if(a==='--host') out.host=argv[++i];
    else if(a==='--port') out.port=Number(argv[++i]);
    else if(a==='--open') out.open=true;
    else if(a==='--json') out.json=true;
    else if(a==='--help'){ console.log('usage: run_builder_studio.sh [--port PORT] [--host HOST] [--open] [--json]'); process.exit(0); }
    else throw new Error(`unknown option ${a}`);
  }
  if(!Number.isSafeInteger(out.port)||out.port<0||out.port>65535) throw new Error('port must be 0..65535');
  return out;
}
function token(){return pathToken;}
function splitLines(stream,onLine){
  let buf=''; stream.setEncoding('utf8'); stream.on('data',(chunk)=>{buf+=chunk; for(;;){const n=buf.indexOf('\n'); if(n<0)break; const line=buf.slice(0,n).replace(/\r$/,''); buf=buf.slice(n+1); onLine(line);}}); stream.on('end',()=>{if(buf)onLine(buf);});
}
function childReady(child, eventName, timeoutMs, label, echoAfter=true){
  return new Promise((resolve,reject)=>{
    let done=false; const timer=setTimeout(()=>{if(done)return; done=true; reject(new Error(`${label} did not become ready within ${timeoutMs}ms`));},timeoutMs);
    splitLines(child.stdout,(line)=>{
      let value=null; try{value=JSON.parse(line);}catch{}
      if(!done&&value?.event===eventName){done=true; clearTimeout(timer); resolve(value); return;}
      if(echoAfter&&line) process.stdout.write(`[${label}] ${line}\n`);
    });
    child.once('exit',(code,signal)=>{if(done)return; done=true; clearTimeout(timer); reject(new Error(`${label} exited before ready (code=${code}, signal=${signal})`));});
    child.once('error',(error)=>{if(done)return; done=true; clearTimeout(timer); reject(error);});
  });
}
function pipeErrors(child,label){splitLines(child.stderr,(line)=>{if(line)process.stderr.write(`[${label}] ${line}\n`);});}

async function startBackend(){
  const env={...process.env,WUIB_BUILDER_ROOT:BUILDER_ROOT,WUIB_BRIDGE_TOKEN:bridgeToken,WUIB_PATH_TOKEN:pathToken,WUIB_STUDIO_PACKAGE:path.join(BUILDER_ROOT,'studio','wire_ui_builder_studio_v0.11.json')};
  backend=spawn(REXX,[path.join(BUILDER_ROOT,'tools','builder_live_backend.rex')],{cwd:BUILDER_ROOT,env,stdio:['ignore','pipe','pipe']});
  pipeErrors(backend,'ooRexx');
  backendInfo=await childReady(backend,'builder-backend-ready',15000,'ooRexx',true);
  return backendInfo;
}
async function startGateway(info){
  const gatewayScript=path.join(GATEWAY_ROOT,'node','gateway.mjs');
  const env={...process.env,
    QF_BRIDGE_HOST:'127.0.0.1',QF_BRIDGE_PORT:String(info.bridgePort),QF_BRIDGE_TOKEN:bridgeToken,
    WIRE_UI_INBOUND_QUEUE:info.inQueue,WIRE_UI_GATEWAY_HOST:'127.0.0.1',WIRE_UI_GATEWAY_PORT:'0',WIRE_UI_GATEWAY_PATH:'/wire-ui',WIRE_UI_GATEWAY_PATH_TOKEN:pathToken,
    WIRE_UI_BOOTSTRAP_PATH:'/wire-ui/bootstrap',WIRE_UI_APPLICATION_ID:info.applicationId,WIRE_UI_SESSION_ID:info.sessionId,WIRE_UI_ACCESS_POINT_ID:info.accessPointId,
    WIRE_UI_MODULE_URL:info.moduleUrl,WIRE_UI_SITE_ID:info.siteId
  };
  gateway=spawn(process.execPath,[gatewayScript],{cwd:GATEWAY_ROOT,env,stdio:['ignore','pipe','pipe']});
  pipeErrors(gateway,'gateway');
  gatewayInfo=await childReady(gateway,'wire-ui-gateway-listening',10000,'gateway',true);
  return gatewayInfo;
}
function contentType(file){
  if(file.endsWith('.html'))return 'text/html; charset=utf-8';
  if(file.endsWith('.css'))return 'text/css; charset=utf-8';
  if(file.endsWith('.js')||file.endsWith('.mjs'))return 'text/javascript; charset=utf-8';
  if(file.endsWith('.json'))return 'application/json; charset=utf-8';
  return 'application/octet-stream';
}
function serveFile(res,root,relative){
  const base=path.resolve(root); const target=path.resolve(base,relative);
  if(target!==base&&!target.startsWith(base+path.sep)){res.writeHead(403);res.end('Forbidden');return;}
  if(!fs.existsSync(target)||!fs.statSync(target).isFile()){res.writeHead(404);res.end('Not found');return;}
  res.writeHead(200,{'content-type':contentType(target),'cache-control':'no-store'}); fs.createReadStream(target).pipe(res);
}
async function fetchGatewayBootstrap(){
  return new Promise((resolve,reject)=>{
    const req=http.get({host:'127.0.0.1',port:gatewayInfo.port,path:`/wire-ui/bootstrap?token=${encodeURIComponent(token())}`,headers:{accept:'application/json'}},(res)=>{
      let text=''; res.setEncoding('utf8'); res.on('data',(c)=>text+=c); res.on('end',()=>{if(res.statusCode!==200)return reject(new Error(`gateway bootstrap returned ${res.statusCode}`)); try{resolve(JSON.parse(text));}catch(e){reject(e);}});
    }); req.on('error',reject);
  });
}
async function startWeb(){
  web=http.createServer(async(req,res)=>{
    try{
      const url=new URL(req.url,'http://builder.local');
      if(req.method!=='GET'){res.writeHead(405);res.end('Method not allowed');return;}
      if(url.pathname==='/healthz'){
        const body=JSON.stringify({ok:true,runtime:'ooRexx/WireUIServer/QueueFabric',backend:backendInfo?.event??null,gateway:gatewayInfo?.event??null,targetProjectId:backendInfo?.targetProjectId??null});
        res.writeHead(200,{'content-type':'application/json; charset=utf-8','cache-control':'no-store'});res.end(body);return;
      }
      if(url.pathname==='/wire-ui/bootstrap'){
        const bootstrap=await fetchGatewayBootstrap();
        bootstrap.gatewayUrl=`ws://127.0.0.1:${gatewayInfo.port}/wire-ui?token=${encodeURIComponent(token())}`;
        res.writeHead(200,{'content-type':'application/json; charset=utf-8','cache-control':'no-store, private','x-content-type-options':'nosniff'});res.end(JSON.stringify(bootstrap));return;
      }
      if(url.pathname.startsWith('/wire-ui-js/')){serveFile(res,JS_ROOT,url.pathname.slice('/wire-ui-js/'.length));return;}
      const rel=url.pathname==='/'?'index.html':url.pathname.slice(1);
      serveFile(res,path.join(BUILDER_ROOT,'web'),rel);
    }catch(error){res.writeHead(500,{'content-type':'text/plain; charset=utf-8','cache-control':'no-store'});res.end(`Builder live host error: ${error.message}`);}
  });
  await new Promise((resolve,reject)=>{web.once('error',reject);web.listen(args.port,args.host,resolve);});
  return web.address();
}
async function maybeOpen(url){
  if(!args.open)return;
  const opener=process.platform==='darwin'?'open':process.platform==='win32'?'cmd':'xdg-open';
  const openArgs=process.platform==='win32'?['/c','start','',url]:[url];
  const child=spawn(opener,openArgs,{stdio:'ignore',detached:true}); child.unref();
}
async function stop(code=0){
  if(stopping)return; stopping=true;
  if(web) await new Promise((resolve)=>web.close(()=>resolve()));
  if(gateway&&!gateway.killed) gateway.kill('SIGTERM');
  if(backend&&!backend.killed) backend.kill('SIGTERM');
  setTimeout(()=>{if(gateway&&!gateway.killed)gateway.kill('SIGKILL');if(backend&&!backend.killed)backend.kill('SIGKILL');process.exit(code);},750).unref();
  await Promise.all([gateway,backend].filter(Boolean).map((c)=>new Promise((resolve)=>{if(c.exitCode!==null)return resolve(); c.once('exit',resolve); setTimeout(resolve,650);}))); process.exit(code);
}

process.on('SIGINT',()=>void stop(0)); process.on('SIGTERM',()=>void stop(0));
try{
  const info=await startBackend();
  const gw=await startGateway(info);
  const addr=await startWeb();
  const publicHost=args.host==='0.0.0.0'?'127.0.0.1':args.host;
  const url=`http://${publicHost}:${addr.port}/`;
  const ready={event:'builder-live-ready',url,healthUrl:`http://${publicHost}:${addr.port}/healthz`,runtime:'ooRexx -> WireUIServer v0.16 -> Queue Fabric -> Web Gateway v0.2 -> Alchemy Wire UI JS v0.4-dev4',targetProjectId:info.targetProjectId,targetRevision:info.targetRevision,targetDraftCount:info.targetDraftCount,gatewayPort:gw.port};
  if(!args.json){
    console.log('Wire UI Builder Studio v0.11 is live.');
    console.log(`Runtime: ${ready.runtime}`);
    console.log(`Target: ${ready.targetProjectId} revision ${ready.targetRevision} (${ready.targetDraftCount} drafts)`);
    console.log(`Open: ${url}`);
    console.log('Stop: Ctrl-C');
  }
  console.log(JSON.stringify(ready));
  await maybeOpen(url);
  backend.once('exit',(code,signal)=>{if(!stopping){console.error(`ooRexx backend exited unexpectedly (code=${code}, signal=${signal})`);void stop(1);}});
  gateway.once('exit',(code,signal)=>{if(!stopping){console.error(`gateway exited unexpectedly (code=${code}, signal=${signal})`);void stop(1);}});
}catch(error){
  console.error(`Wire UI Builder live launch failed: ${error.stack||error}`);
  await stop(1);
}
