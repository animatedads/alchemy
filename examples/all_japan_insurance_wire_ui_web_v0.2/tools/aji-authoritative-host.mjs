#!/usr/bin/env node
import { spawn } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'..');

function parseArgs(argv){
  const out={host:'127.0.0.1',port:8090,rexx:process.env.AJI_OOREXX||'rexx',rexxLib:process.env.AJI_OOREXX_LIB||'',sessionId:process.env.AJI_WUI_SESSION_ID||'AJI-DEV-SESSION',json:false};
  for(let i=0;i<argv.length;i++){
    const a=argv[i]; const value=()=>{if(i+1>=argv.length)throw new Error(`${a} requires a value`);return argv[++i];};
    if(a==='--host')out.host=value(); else if(a==='--port')out.port=Number(value()); else if(a==='--rexx')out.rexx=value(); else if(a==='--rexx-lib')out.rexxLib=value(); else if(a==='--session-id')out.sessionId=value(); else if(a==='--json')out.json=true; else if(a==='-h'||a==='--help'){console.log('Usage: node tools/aji-authoritative-host.mjs [--host 127.0.0.1] [--port 8090] [--rexx PATH] [--rexx-lib DIR] [--session-id ID] [--json]');process.exit(0);} else throw new Error(`unknown argument: ${a}`);
  }
  if(!Number.isInteger(out.port)||out.port<1||out.port>65535)throw new Error('port must be 1..65535');
  return out;
}
const args=parseArgs(process.argv.slice(2));
const backendScript=path.join(root,'runtime','aji_wire_ui_backend.rex');
const releaseFile=path.join(root,'runtime','aji-compiled-release.json');
const gatewayScript=path.join(root,'vendor','web_gateway_v0.2','node','gateway.mjs');
for(const f of [backendScript,releaseFile,gatewayScript]) if(!fs.existsSync(f)) throw new Error(`AJI live runtime missing: ${f}`);

const token=()=>crypto.randomBytes(24).toString('base64url');
const bridgeToken=token(), pathToken=token();
let backend=null,gateway=null,stopping=false;

function rexxPath(){
  const dirs=[
    path.dirname(path.resolve(args.rexx)),
    path.join(root,'runtime'),
    path.join(root,'vendor','wire_ui_server_v0.17','src'),
    path.join(root,'vendor','queue_fabric_v0.9-dev4','src'),
    path.join(root,'vendor','web_gateway_v0.2','src'),
    path.join(root,'vendor','alchemy_objects_v0.8','src'),
    path.join(root,'vendor','oorexx_crypto_v0.5','src')
  ];
  if(process.env.REXX_PATH)dirs.push(process.env.REXX_PATH);
  return dirs.join(path.delimiter);
}
function childReady(child,event,timeoutMs,label){
  return new Promise((resolve,reject)=>{
    let buffer='',stderr='',settled=false;
    const timer=setTimeout(()=>{if(!settled){settled=true;reject(new Error(`${label} did not become ready: ${stderr}`));}},timeoutMs);
    child.stderr.setEncoding('utf8'); child.stderr.on('data',d=>{stderr+=d; if(!args.json)process.stderr.write(`[${label}] ${d}`);});
    child.stdout.setEncoding('utf8'); child.stdout.on('data',d=>{
      if(settled){if(!args.json)process.stdout.write(`[${label}] ${d}`);return;}
      buffer+=d;
      for(;;){const nl=buffer.indexOf('\n');if(nl<0)break;const line=buffer.slice(0,nl).trim();buffer=buffer.slice(nl+1);if(!line)continue;try{const obj=JSON.parse(line);if(obj?.event===event){settled=true;clearTimeout(timer);resolve(obj);return;}}catch{} if(!args.json)process.stdout.write(`[${label}] ${line}\n`);}
    });
    child.once('exit',(code,signal)=>{if(!settled){settled=true;clearTimeout(timer);reject(new Error(`${label} exited before ready (code=${code}, signal=${signal}): ${stderr}`));}});
  });
}

async function startBackend(){
  const env={...process.env,
    REXX_PATH:rexxPath(),
    AJI_WUI_BRIDGE_TOKEN:bridgeToken,
    AJI_WUI_PATH_TOKEN:pathToken,
    AJI_WUI_SESSION_ID:args.sessionId,
    AJI_WUI_COMPILED_RELEASE:releaseFile
  };
  if(args.rexxLib)env.LD_LIBRARY_PATH=`${args.rexxLib}${process.env.LD_LIBRARY_PATH?path.delimiter+process.env.LD_LIBRARY_PATH:''}`;
  backend=spawn(args.rexx,[backendScript],{cwd:root,env,stdio:['ignore','pipe','pipe']});
  return childReady(backend,'aji-wire-ui-backend-ready',15000,'ooRexx');
}
async function startGateway(info){
  const env={...process.env,
    QF_BRIDGE_HOST:'127.0.0.1',QF_BRIDGE_PORT:String(info.bridgePort),QF_BRIDGE_TOKEN:bridgeToken,
    WIRE_UI_INBOUND_QUEUE:info.inQueue,
    WIRE_UI_GATEWAY_HOST:args.host,WIRE_UI_GATEWAY_PORT:String(args.port),WIRE_UI_GATEWAY_PATH:'/wire-ui',WIRE_UI_GATEWAY_PATH_TOKEN:pathToken,
    WIRE_UI_BOOTSTRAP_PATH:'/wire-ui/bootstrap',WIRE_UI_APPLICATION_ID:info.applicationId,WIRE_UI_SESSION_ID:info.sessionId,WIRE_UI_ACCESS_POINT_ID:info.accessPointId,
    WIRE_UI_MODULE_URL:info.moduleUrl,WIRE_UI_SITE_ID:info.siteId
  };
  gateway=spawn(process.execPath,[gatewayScript],{cwd:path.dirname(gatewayScript),env,stdio:['ignore','pipe','pipe']});
  return childReady(gateway,'wire-ui-gateway-listening',10000,'gateway');
}
async function stop(code=0){
  if(stopping)return;stopping=true;
  if(gateway&&!gateway.killed)gateway.kill('SIGTERM');
  if(backend&&!backend.killed)backend.kill('SIGTERM');
  await new Promise(r=>setTimeout(r,250));
  if(gateway&&!gateway.killed)gateway.kill('SIGKILL');
  if(backend&&!backend.killed)backend.kill('SIGKILL');
  process.exit(code);
}
process.on('SIGINT',()=>void stop(0));process.on('SIGTERM',()=>void stop(0));

try{
  const info=await startBackend();
  const gw=await startGateway(info);
  const publicHost=args.host==='0.0.0.0'?'127.0.0.1':args.host;
  const bootstrapUrl=`http://${publicHost}:${gw.port}/wire-ui/bootstrap?token=${encodeURIComponent(pathToken)}`;
  const gatewayUrl=`ws://${publicHost}:${gw.port}/wire-ui?token=${encodeURIComponent(pathToken)}`;
  const ready={event:'aji-authoritative-wire-ui-ready',bootstrapUrl,gatewayUrl,host:args.host,port:gw.port,applicationId:info.applicationId,sessionId:info.sessionId,accessPointId:info.accessPointId,releaseId:info.releaseId,releaseVersion:info.releaseVersion,releaseContentAddress:info.releaseContentAddress,projectionMode:info.projectionMode};
  if(!args.json){
    console.log('All Japan Insurance authoritative Wire UI development service is live.');
    console.log(`Bootstrap: ${bootstrapUrl}`);
    console.log(`Release: ${info.releaseId}@${info.releaseVersion}`);
    console.log(`Projection: ${info.projectionMode}`);
    console.log('Stop: Ctrl-C');
  }
  console.log(JSON.stringify(ready));
  backend.once('exit',(code,signal)=>{if(!stopping){console.error(`AJI ooRexx backend exited (code=${code}, signal=${signal})`);void stop(1);}});
  gateway.once('exit',(code,signal)=>{if(!stopping){console.error(`AJI gateway exited (code=${code}, signal=${signal})`);void stop(1);}});
}catch(error){console.error(`AJI authoritative Wire UI launch failed: ${error.stack||error}`);await stop(1);}
