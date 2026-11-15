/** Development-only HTTP access point for the real NotNotes Wire UI session.
 * Wire business semantics live exclusively in ooRexx NotNotes/Server; this
 * Node process only serves static assets and the existing WebSocket edge. */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {QueueBackendClient} from '../oorexx_queue_fabric_web_gateway_v0.2/node/queue-backend-client.mjs';
import {QueueFabricWebSocketEdge} from '../oorexx_queue_fabric_web_gateway_v0.2/node/websocket-edge.mjs';
const HERE=path.dirname(fileURLToPath(import.meta.url));
const appRoot=path.resolve(HERE,'../wire_ui_builder_v0.6/web/notnotes');
const jsRoot=path.resolve(HERE,'../alchemy_wire_ui_js_v0.4-dev6');
const host='127.0.0.1';
const port=Number(fs.readFileSync(path.join(HERE,'port'),'utf8').trim());
const edge=new QueueFabricWebSocketEdge({
  backend:new QueueBackendClient({host,port,bridgeToken:'notnotes-dev-bridge-token'}),
  inboundQueue:'WIREUI.IN.AP1',host,port:0,path:'/wire-ui',pollMs:10
});
await edge.start();
let httpPort=0;
const mime=(name)=> name.endsWith('.js')||name.endsWith('.mjs')?'text/javascript; charset=utf-8':name.endsWith('.css')?'text/css; charset=utf-8':name.endsWith('.json')?'application/json; charset=utf-8':'text/html; charset=utf-8';
const send=(res,status,body,type='text/plain; charset=utf-8')=>{res.writeHead(status,{'content-type':type,'cache-control':'no-store','x-content-type-options':'nosniff'});res.end(body);};
const web=http.createServer((req,res)=>{
  const u=new URL(req.url,'http://localhost');
  if(req.method!=='GET')return send(res,405,'Method Not Allowed');
  if(u.pathname==='/wire-ui/bootstrap')return send(res,200,JSON.stringify({
    moduleUrl:'/wire-js/src/index.js',gatewayUrl:`ws://${host}:${edge.port}/wire-ui`,
    outboundQueue:'WIREUI.IN.AP1',siteId:'NOTNOTES_WEB_WIRE',
    ownership:{applicationId:'NOTNOTES',sessionId:'S1',accessPointId:'AP1'}
  }),'application/json; charset=utf-8');
  if(u.pathname==='/demo.css')return send(res,200,fs.readFileSync(path.join(HERE,'demo.css')),'text/css; charset=utf-8');
  if(u.pathname==='/acceptance.mjs')return send(res,200,fs.readFileSync(path.join(HERE,'acceptance.mjs')),'text/javascript; charset=utf-8');
  if(u.pathname==='/' || u.pathname==='/live.html'){
    let html=fs.readFileSync(path.join(appRoot,'live.html'),'utf8');
    html=html.replace('type="application/json">{}</script>','type="application/json">{"configUrl":"/wire-ui/bootstrap"}</script>');
    html=html.replace('</head>','<link rel="stylesheet" href="/demo.css"></head>');
    if(u.searchParams.get('acceptance')==='1')html=html.replace('</body>','<script type="module" src="/acceptance.mjs"></script></body>');
    return send(res,200,html,'text/html; charset=utf-8');
  }
  let root,relative;
  if(u.pathname.startsWith('/wire-js/')){root=jsRoot;relative=u.pathname.slice('/wire-js/'.length);}
  else {root=appRoot;relative=u.pathname.replace(/^\//,'');}
  const resolved=path.resolve(root,relative);
  if(!resolved.startsWith(root+path.sep) || !fs.existsSync(resolved)||!fs.statSync(resolved).isFile())return send(res,404,'Not found');
  return send(res,200,fs.readFileSync(resolved),mime(resolved));
});
await new Promise((resolve,reject)=>{web.once('error',reject);web.listen(0,host,resolve);});
httpPort=web.address().port;
fs.writeFileSync(path.join(HERE,'http-port'),String(httpPort));
console.log(JSON.stringify({event:'NOTNOTES_WEB_READY',url:`http://${host}:${httpPort}/live.html`,gatewayPort:edge.port}));
async function close(){ await new Promise(r=>web.close(r));await edge.stop();process.exit(0);}
process.once('SIGTERM',()=>void close());process.once('SIGINT',()=>void close());
