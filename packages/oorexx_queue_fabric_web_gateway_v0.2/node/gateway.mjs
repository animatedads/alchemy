import { QueueBackendClient } from './queue-backend-client.mjs';
import { QueueFabricWebSocketEdge } from './websocket-edge.mjs';

const need=(name)=>{const v=process.env[name]; if(!v) throw new Error(`${name} is required`); return v;};
const optionalBootstrap=()=>{
  const names=['WIRE_UI_APPLICATION_ID','WIRE_UI_SESSION_ID','WIRE_UI_ACCESS_POINT_ID','WIRE_UI_MODULE_URL'];
  const present=names.filter((name)=>process.env[name]);
  if(!present.length) return null;
  if(present.length!==names.length) throw new Error(`browser bootstrap requires ${names.join(', ')}`);
  return Object.freeze({
    moduleUrl:process.env.WIRE_UI_MODULE_URL,
    siteId:process.env.WIRE_UI_SITE_ID??'WIRE_UI',
    ownership:Object.freeze({
      applicationId:process.env.WIRE_UI_APPLICATION_ID,
      sessionId:process.env.WIRE_UI_SESSION_ID,
      accessPointId:process.env.WIRE_UI_ACCESS_POINT_ID
    })
  });
};

const backend=new QueueBackendClient({
  host:process.env.QF_BRIDGE_HOST??'127.0.0.1',
  port:Number(need('QF_BRIDGE_PORT')),
  bridgeToken:need('QF_BRIDGE_TOKEN')
});
const edge=new QueueFabricWebSocketEdge({
  backend,
  inboundQueue:need('WIRE_UI_INBOUND_QUEUE'),
  host:process.env.WIRE_UI_GATEWAY_HOST??'127.0.0.1',
  port:Number(process.env.WIRE_UI_GATEWAY_PORT??0),
  path:process.env.WIRE_UI_GATEWAY_PATH??'/wire-ui',
  pathToken:process.env.WIRE_UI_GATEWAY_PATH_TOKEN??'',
  bootstrap:optionalBootstrap(),
  bootstrapPath:process.env.WIRE_UI_BOOTSTRAP_PATH??undefined,
  publicGatewayUrl:process.env.WIRE_UI_PUBLIC_GATEWAY_URL??''
});
await edge.start();
console.log(JSON.stringify({
  event:'wire-ui-gateway-listening',
  host:edge.host,
  port:edge.port,
  path:edge.path,
  bootstrapPath:edge.bootstrap?edge.bootstrapPath:null
}));
let stopping=false;
const stop=async()=>{if(stopping)return; stopping=true; await edge.stop(); process.exit(0);};
process.on('SIGINT',stop); process.on('SIGTERM',stop);
