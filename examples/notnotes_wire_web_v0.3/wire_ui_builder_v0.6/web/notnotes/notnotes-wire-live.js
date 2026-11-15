import {parseNotNotesSeed,loadNotNotesBootstrap} from './live-config.js';

const mount=document.getElementById('notnotes-wire-root');
const statusNode=document.getElementById('notnotes-wire-connection');
const configNode=document.getElementById('notnotes-wire-config');

function status(text,state=''){
  statusNode.textContent=text;
  statusNode.dataset.state=state;
}

function requireConfig(config){
  for(const name of ['moduleUrl','gatewayUrl','outboundQueue']){
    if(!config?.[name]) throw new Error(`notNotes Web Wire bootstrap requires ${name}`);
  }
  for(const name of ['applicationId','sessionId','accessPointId']){
    if(!config?.ownership?.[name]) throw new Error(`notNotes Web Wire bootstrap requires ownership.${name}`);
  }
  return config;
}

function capabilities(){
  return {
    viewportClass:globalThis.matchMedia?.('(max-width: 820px)').matches?'compact':'large',
    pointer:globalThis.matchMedia?.('(pointer: coarse)').matches?'coarse':'fine',
    features:{dialog:'HTMLDialogElement' in globalThis,resizeObserver:'ResizeObserver' in globalThis}
  };
}

async function boot(){
  const seed=parseNotNotesSeed(configNode?.textContent||'{}');
  const config=requireConfig(await loadNotNotesBootstrap(seed));
  const api=await import(config.moduleUrl);
  const {
    QueueFabricGatewayTransport,Comms,DefinitionRegistry,BrowserRenderer,
    WireUIRuntime,RenderProfileController,WireUIJourneyController,
    ObservationPlan,LocalStorageDefinitionCache,MaterialController
  }=api;

  const transport=new QueueFabricGatewayTransport({
    url:config.gatewayUrl,
    outboundQueue:config.outboundQueue,
    ownership:config.ownership,
    putResultMode:'required'
  });
  const comms=new Comms({
    transport,
    source:config.ownership.accessPointId,
    destination:config.outboundQueue
  });
  const definitions=new DefinitionRegistry();
  const renderer=new BrowserRenderer({definitions,mount,document});
  const definitionCache=new LocalStorageDefinitionCache({storage:globalThis.localStorage});
  const material=new MaterialController({comms,document});
  const profile=new RenderProfileController({
    comms,definitions,definitionCache,renderer,
    siteId:config.siteId??'NOTNOTES_WEB_WIRE',
    capabilities:capabilities()
  });
  const runtime=new WireUIRuntime({
    comms,definitions,renderer,serverSemantic:true,
    renderProfile:profile,ownership:config.ownership
  });
  const journey=new WireUIJourneyController({comms,runtime});
  const observation=new ObservationPlan({comms});

  comms.onState((event)=>{
    if(event.type==='connected') status('Transport connected · loading view','sync');
    else if(event.type==='closed') status('Disconnected','closed');
    else if(event.type==='sequence-gap') status('Synchronising…','sync');
    else if(event.type==='inbound-handler-error') status('Resynchronising…','error');
  });

  comms.onAny((_payload, envelope)=>{
    if(envelope?.kind==='UI_VIEW_PATCH' && runtime.waitingForResync) status('Synchronising…','sync');
    else if(runtime.viewRef && Number.isSafeInteger(runtime.revision) && !runtime.waitingForResync && !runtime.actionsBlockedByAuthority) status('View ready','live');
  });
  await comms.connect(profile.helloPayload({accessPointId:config.ownership.accessPointId}));
  globalThis.__notNotesWire=Object.freeze({comms,runtime,renderer,definitions,profile,material,journey,observation});
}

boot().catch((error)=>{
  console.error('notNotes Web Wire bootstrap failed',error);
  status('Unable to connect','error');
  mount.replaceChildren();
  const panel=document.createElement('section');
  panel.className='nn-bootstrap-error';
  panel.textContent='notNotes could not establish this Wire UI session.';
  mount.appendChild(panel);
});
