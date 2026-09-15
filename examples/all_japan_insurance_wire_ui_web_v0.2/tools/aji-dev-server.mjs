#!/usr/bin/env node
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const pkgRoot=path.resolve(here,'..');
const webRoot=path.join(pkgRoot,'web');

function parseArgs(argv){
  const o={host:'127.0.0.1',port:8080,mode:'preview',bootstrapUrl:'',bootstrapFile:'',wireUiJsRoot:''};
  for(let i=0;i<argv.length;i+=1){ const a=argv[i]; const v=()=>{ if(i+1>=argv.length) throw new Error(`${a} requires a value`); return argv[++i]; };
    if(a==='--host') o.host=v(); else if(a==='--port') o.port=Number(v()); else if(a==='--mode') o.mode=v(); else if(a==='--bootstrap-url') o.bootstrapUrl=v(); else if(a==='--bootstrap-file') o.bootstrapFile=path.resolve(v()); else if(a==='--wire-ui-js-root') o.wireUiJsRoot=path.resolve(v()); else throw new Error(`unknown argument: ${a}`); }
  if(!Number.isInteger(o.port)||o.port<0||o.port>65535) throw new Error('port must be 0..65535');
  if(!['preview','live'].includes(o.mode)) throw new Error('mode must be preview or live');
  if(o.bootstrapUrl&&o.bootstrapFile) throw new Error('use either --bootstrap-url or --bootstrap-file, not both');
  if(o.mode==='live'&&!o.bootstrapUrl&&!o.bootstrapFile) throw new Error('live mode requires --bootstrap-url or --bootstrap-file');
  return o;
}
const opts=parseArgs(process.argv.slice(2));
const mime=new Map([['.html','text/html; charset=utf-8'],['.js','text/javascript; charset=utf-8'],['.mjs','text/javascript; charset=utf-8'],['.css','text/css; charset=utf-8'],['.json','application/json; charset=utf-8'],['.png','image/png'],['.svg','image/svg+xml'],['.txt','text/plain; charset=utf-8']]);
function safeJoin(root,urlPath){ const rel=decodeURIComponent(urlPath.split('?')[0]).replace(/^\/+/, ''); const r=path.resolve(root,rel); const base=path.resolve(root)+path.sep; return r===path.resolve(root)||r.startsWith(base)?r:null; }
function sendJson(res,code,value){const b=Buffer.from(JSON.stringify(value));res.writeHead(code,{'content-type':'application/json; charset=utf-8','cache-control':'no-store, private','content-length':b.length});res.end(b);}
function sendFile(res,filePath){let s;try{s=fs.statSync(filePath)}catch{return false}if(!s.isFile())return false;const type=mime.get(path.extname(filePath).toLowerCase())||'application/octet-stream';res.writeHead(200,{'content-type':type,'cache-control':type.startsWith('text/html')?'no-store':'no-cache','content-length':s.size});fs.createReadStream(filePath).pipe(res);return true;}
function rewriteBootstrap(v){return opts.wireUiJsRoot?{...v,moduleUrl:'/__wire_ui_runtime__/src/index.js'}:v;}
async function bootstrapValue(){ if(opts.bootstrapFile)return rewriteBootstrap(JSON.parse(fs.readFileSync(opts.bootstrapFile,'utf8'))); const r=await fetch(opts.bootstrapUrl,{method:'GET',headers:{accept:'application/json'},cache:'no-store'});if(!r.ok)throw new Error(`upstream bootstrap returned ${r.status}`);return rewriteBootstrap(await r.json()); }
const server=http.createServer(async(req,res)=>{try{const u=new URL(req.url||'/',`http://${req.headers.host||'localhost'}`);let p=u.pathname;if(p==='/__health')return sendJson(res,200,{ok:true,mode:opts.mode,siteId:'ALL_JAPAN_INSURANCE'});if(opts.mode==='live'&&p==='/wire-ui/bootstrap'){try{return sendJson(res,200,await bootstrapValue())}catch(e){return sendJson(res,502,{ok:false,code:'BOOTSTRAP_UNAVAILABLE',detail:e.message})}}if(p.startsWith('/__wire_ui_runtime__/')){if(!opts.wireUiJsRoot)return sendJson(res,404,{ok:false,code:'WIRE_UI_RUNTIME_NOT_CONFIGURED'});const f=safeJoin(opts.wireUiJsRoot,p.slice('/__wire_ui_runtime__/'.length));if(!f||!sendFile(res,f))return sendJson(res,404,{ok:false,code:'NOT_FOUND'});return;}if(p==='/')p=opts.mode==='preview'?'/preview.html':'/index.html';const f=safeJoin(webRoot,p);if(!f||!sendFile(res,f))return sendJson(res,404,{ok:false,code:'NOT_FOUND'});}catch(e){sendJson(res,500,{ok:false,code:'SERVER_ERROR',detail:e.message})}});
server.listen(opts.port,opts.host,()=>{const a=server.address();const port=typeof a==='object'&&a?a.port:opts.port;const host=opts.host==='0.0.0.0'?'127.0.0.1':opts.host;console.log(`All Japan Insurance Wire UI (${opts.mode})`);console.log(`AJI_WIRE_UI_URL=http://${host}:${port}/`);if(opts.mode==='live')console.log('Wire UI bootstrap is exposed locally at /wire-ui/bootstrap');});
function stop(){server.close(()=>process.exit(0));setTimeout(()=>process.exit(1),2000).unref()}process.on('SIGINT',stop);process.on('SIGTERM',stop);
