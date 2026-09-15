#!/usr/bin/env node
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'..');
function parse(argv){
  const o={host:'127.0.0.1',port:8082,authoritativeHost:'127.0.0.1',authoritativePort:8090,rexx:process.env.AJI_OOREXX||'rexx',rexxLib:process.env.AJI_OOREXX_LIB||'',sessionId:process.env.AJI_WUI_SESSION_ID||'AJI-DEV-SESSION'};
  for(let i=0;i<argv.length;i++){const a=argv[i];const v=()=>{if(i+1>=argv.length)throw new Error(`${a} requires a value`);return argv[++i];};
    if(a==='--host')o.host=v();else if(a==='--port')o.port=Number(v());else if(a==='--authoritative-host')o.authoritativeHost=v();else if(a==='--authoritative-port')o.authoritativePort=Number(v());else if(a==='--rexx')o.rexx=v();else if(a==='--rexx-lib')o.rexxLib=v();else if(a==='--session-id')o.sessionId=v();else if(a==='-h'||a==='--help'){console.log('Usage: node tools/aji-full-live-host.mjs [--host 127.0.0.1] [--port 8082] [--authoritative-port 8090] [--rexx PATH] [--rexx-lib DIR]');process.exit(0);}else throw new Error(`unknown argument: ${a}`);}
  return o;
}
const args=parse(process.argv.slice(2));
let authority=null,web=null,stopping=false;
function waitJson(child,event,timeout=20000){return new Promise((resolve,reject)=>{let buf='';const t=setTimeout(()=>reject(new Error(`${event} timeout`)),timeout);child.stdout.setEncoding('utf8');child.stdout.on('data',d=>{buf+=d;for(;;){const n=buf.indexOf('\n');if(n<0)break;const line=buf.slice(0,n).trim();buf=buf.slice(n+1);if(!line)continue;try{const o=JSON.parse(line);if(o?.event===event){clearTimeout(t);resolve(o);return;}}catch{}console.log(line);}});child.stderr.pipe(process.stderr);child.once('exit',(c,s)=>reject(new Error(`child exited before ${event}: ${c}/${s}`)));});}
function waitWeb(child,timeout=10000){return new Promise((resolve,reject)=>{let buf='';const t=setTimeout(()=>reject(new Error('web startup timeout')),timeout);child.stdout.setEncoding('utf8');child.stdout.on('data',d=>{buf+=d;for(;;){const n=buf.indexOf('\n');if(n<0)break;const line=buf.slice(0,n).trim();buf=buf.slice(n+1);if(!line)continue;console.log(line);if(line.startsWith('AJI_WIRE_UI_URL=')){clearTimeout(t);resolve(line.slice('AJI_WIRE_UI_URL='.length));return;}}});child.stderr.pipe(process.stderr);child.once('exit',(c,s)=>reject(new Error(`web exited before ready: ${c}/${s}`)));});}
async function stop(code=0){if(stopping)return;stopping=true;if(web&&!web.killed)web.kill('SIGTERM');if(authority&&!authority.killed)authority.kill('SIGTERM');await new Promise(r=>setTimeout(r,300));if(web&&!web.killed)web.kill('SIGKILL');if(authority&&!authority.killed)authority.kill('SIGKILL');process.exit(code);}
process.on('SIGINT',()=>void stop(0));process.on('SIGTERM',()=>void stop(0));
try{
  const authorityArgs=[path.join(root,'tools','aji-authoritative-host.mjs'),'--host',args.authoritativeHost,'--port',String(args.authoritativePort),'--rexx',args.rexx,'--session-id',args.sessionId,'--json'];
  if(args.rexxLib)authorityArgs.push('--rexx-lib',args.rexxLib);
  authority=spawn(process.execPath,authorityArgs,{cwd:root,stdio:['ignore','pipe','pipe']});
  const ready=await waitJson(authority,'aji-authoritative-wire-ui-ready');
  web=spawn(process.execPath,[path.join(root,'tools','aji-dev-server.mjs'),'--mode','live','--host',args.host,'--port',String(args.port),'--bootstrap-url',ready.bootstrapUrl,'--wire-ui-js-root',path.join(root,'vendor','alchemy_wire_ui_js_v0.4-dev4')],{cwd:root,stdio:['ignore','pipe','pipe']});
  const url=await waitWeb(web);
  console.log(`AJI_AUTHORITATIVE_BOOTSTRAP=${ready.bootstrapUrl}`);
  console.log(`AJI_RELEASE=${ready.releaseId}@${ready.releaseVersion}`);
  console.log(`AJI_PROJECTION_MODE=${ready.projectionMode}`);
  console.log(`Open: ${url}`);
  console.log('Stop: Ctrl-C');
  authority.once('exit',(c,s)=>{if(!stopping){console.error(`authoritative service exited: ${c}/${s}`);void stop(1);}});
  web.once('exit',(c,s)=>{if(!stopping){console.error(`web shell exited: ${c}/${s}`);void stop(1);}});
}catch(e){console.error(`AJI full live launch failed: ${e.stack||e}`);await stop(1);}
