import {BuilderCompositionController} from './composition-controller.js';
import {parseBootstrapSeed,loadWireUIBootstrap} from './bootstrap-config.js';
const statusNode=document.getElementById('wire-ui-connection');
const mount=document.getElementById('wire-ui-root');
const configNode=document.getElementById('wire-ui-builder-config');
function status(text,state=''){statusNode.textContent=text;statusNode.dataset.state=state;}
function requireConfig(config){
  for(const name of ['moduleUrl','gatewayUrl','outboundQueue']) if(!config?.[name]) throw new Error(`Wire UI Builder bootstrap requires ${name}`);
  for(const name of ['applicationId','sessionId','accessPointId']) if(!config?.ownership?.[name]) throw new Error(`Wire UI Builder bootstrap requires ownership.${name}`);
  return config;
}
async function boot(){
  const seed=parseBootstrapSeed(configNode?.textContent||'{}');
  const config=requireConfig(await loadWireUIBootstrap(seed));
  const api=await import(config.moduleUrl);
  const {QueueFabricGatewayTransport,Comms,DefinitionRegistry,BrowserRenderer,WireUIRuntime,RenderProfileController,WireUIJourneyController,ObservationPlan,LocalStorageDefinitionCache,MaterialController}=api;
  const transport=new QueueFabricGatewayTransport({url:config.gatewayUrl,outboundQueue:config.outboundQueue,ownership:config.ownership,putResultMode:'required'});
  const comms=new Comms({transport,source:config.ownership.accessPointId,destination:config.outboundQueue});
  const definitions=new DefinitionRegistry();
  const material=new MaterialController({comms,document});
  const renderer=new BrowserRenderer({definitions,mount,document});
  const definitionCache=new LocalStorageDefinitionCache({storage:globalThis.localStorage});
  const profile=new RenderProfileController({comms,definitions,definitionCache,renderer,siteId:config.siteId??'WIRE_UI_BUILDER_STUDIO'});
  const runtime=new WireUIRuntime({comms,definitions,renderer,serverSemantic:true,renderProfile:profile,ownership:config.ownership});
  const journey=new WireUIJourneyController({comms,runtime}); new ObservationPlan({comms});
  const composition=new BuilderCompositionController({comms,runtime,renderer,definitions,mount,journeyController:journey,ownership:config.ownership}); composition.start();
  comms.onState((event)=>{if(event.type==='connected')status('Live','live');else if(event.type==='closed')status('Disconnected','closed');else if(event.type==='sequence-gap')status('Synchronising…','sync');else if(event.type==='inbound-handler-error')status('Resynchronising…','error');});
  await comms.connect(profile.helloPayload({accessPointId:config.ownership.accessPointId}));
  globalThis.__wireUIBuilder=Object.freeze({comms,runtime,renderer,definitions,profile,material,journey,composition});
}
boot().catch((error)=>{console.error('Wire UI Builder bootstrap failed',error);status('Unable to connect','error');mount.replaceChildren();const panel=document.createElement('section');panel.className='builder-bootstrap-error';panel.textContent='The Builder could not establish this authoring session.';mount.appendChild(panel);});
