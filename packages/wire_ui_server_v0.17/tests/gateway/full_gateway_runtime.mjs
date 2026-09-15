import assert from 'node:assert/strict';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const HERE=path.dirname(fileURLToPath(import.meta.url));
const gatewayRoot=process.env.WIRE_UI_GATEWAY_SRC;
const jsRoot=process.env.WIRE_UI_JS_SRC;
const rexx=process.env.REXX;
if (!gatewayRoot) throw new Error('WIRE_UI_GATEWAY_SRC is required');
if (!jsRoot) throw new Error('WIRE_UI_JS_SRC is required');
if (!rexx) throw new Error('REXX is required');

const gatewayApi=await import(pathToFileURL(path.join(gatewayRoot,'src/index.js')).href);
const js=await import(pathToFileURL(path.join(jsRoot,'src/index.js')).href);
const { OoRexxQueueFabricPort, WireUIQueueGateway, StaticBindingResolver }=gatewayApi;
const {
  QueueFabricGatewayTransport, Comms, DefinitionRegistry, MemoryRenderer,
  WireUIRuntime, RenderProfileController, MemoryDefinitionCache, MessageKind
}=js;

function waitFor(fn, timeout=5000, interval=10) {
  const start=Date.now();
  return new Promise((resolve,reject)=>{
    const poll=()=>{
      try { const v=fn(); if (v) return resolve(v); }
      catch (e) { return reject(e); }
      if (Date.now()-start>=timeout) return reject(new Error('timed out waiting for Wire UI state'));
      setTimeout(poll,interval);
    };
    poll();
  });
}

const port=new OoRexxQueueFabricPort({
  rexx,
  bridgeScript:path.join(HERE,'full_session_bridge.rex'),
  cwd:HERE,
  env:{...process.env},
  args:['WIREUI.IN.AP1','WIREUI.OUT.AP1','wireui-gateway','WIREUI','']
});
await port.start();
const gateway=await new WireUIQueueGateway({
  queuePort:port,
  bindingResolver:new StaticBindingResolver({flylo:{inboundQueue:'WIREUI.IN.AP1',outboundQueue:'WIREUI.OUT.AP1',principal:'wireui-gateway'}}),
  pollIntervalMs:5
}).listen();

try {
  const transport=new QueueFabricGatewayTransport({
    url:`ws://127.0.0.1:${gateway.port}/wire-ui?binding=flylo`,
    outboundQueue:'WIREUI.IN.AP1',
    ownership:{applicationId:'FLYLO',sessionId:'S1',accessPointId:'AP1'},
    WebSocketImpl:WebSocket,
    putResultMode:'required'
  });
  const comms=new Comms({transport,source:'FLYLO.RUNTIME',destination:'WIREUI.IN.AP1'});
  const definitions=new DefinitionRegistry();
  const renderer=new MemoryRenderer({definitions});
  const cache=new MemoryDefinitionCache();
  const profile=new RenderProfileController({
    comms,definitions,definitionCache:cache,renderer,siteId:'FLYLO',
    capabilities:{viewportClass:'large',pointer:'fine',reducedMotion:false,colourScheme:'light',features:{dialog:true,adoptedStyleSheets:true,resizeObserver:true}}
  });
  new WireUIRuntime({
    comms,definitions,renderer,serverSemantic:true,renderProfile:profile,
    ownership:{applicationId:'FLYLO',sessionId:'S1',accessPointId:'AP1'}
  });
  let renderProfileSeen=null;
  let definitionRequests=0;
  comms.on(MessageKind.UI_RENDER_PROFILE,(payload)=>{renderProfileSeen=payload;});
  const originalSend=comms.send.bind(comms);
  comms.send=async (kind,payload,options)=>{
    if (kind===MessageKind.UI_DEFINITION_REQUIRED) definitionRequests += 1;
    return originalSend(kind,payload,options);
  };

  await comms.connect(profile.helloPayload({applicationId:'FLYLO',sessionId:'S1',accessPointId:'AP1'}));
  await waitFor(()=>renderer.getInstance('ask') && renderer.getInstance('answer'));
  assert.equal(renderProfileSeen.profileId,'large-fine');
  assert.match(renderProfileSeen.manifestId,/^wui-manifest-/);
  assert.equal(definitions.has('ASK_TRIGGER',1),true);
  assert.ok(definitionRequests>=1);
  assert.equal(renderer.getInstance('answer').slots.value,'Ask FlyLo is ready.');

  renderer.emitAction('ask','ASSISTANT.OPEN');
  await waitFor(()=>renderer.getInstance('answer')?.slots?.value?.includes('Nothing has been added to your booking.'));
  assert.match(renderer.getInstance('answer').slots.value,/Nothing has been added to your booking\./);

  const inDepth=await port.depth('WIREUI.IN.AP1','wireui-gateway');
  assert.equal(inDepth.value.total,0);
  await comms.close();

  // Fresh access-point runtime, same persistent definition cache: the server
  // still emits the exact manifest, but JS resolves it locally and sends zero
  // UI_DEFINITION_REQUIRED messages. Authoritative view state is reconstructed.
  const transport2=new QueueFabricGatewayTransport({
    url:`ws://127.0.0.1:${gateway.port}/wire-ui?binding=flylo`,
    outboundQueue:'WIREUI.IN.AP1',
    ownership:{applicationId:'FLYLO',sessionId:'S1',accessPointId:'AP1'},
    WebSocketImpl:WebSocket,
    putResultMode:'required'
  });
  const comms2=new Comms({transport:transport2,source:'FLYLO.RUNTIME.RELOAD',destination:'WIREUI.IN.AP1'});
  const definitions2=new DefinitionRegistry();
  const renderer2=new MemoryRenderer({definitions:definitions2});
  const profile2=new RenderProfileController({
    comms:comms2,definitions:definitions2,definitionCache:cache,renderer:renderer2,siteId:'FLYLO',
    capabilities:{viewportClass:'large',pointer:'fine',reducedMotion:false,colourScheme:'light',features:{dialog:true,adoptedStyleSheets:true,resizeObserver:true}}
  });
  new WireUIRuntime({
    comms:comms2,definitions:definitions2,renderer:renderer2,serverSemantic:true,renderProfile:profile2,
    ownership:{applicationId:'FLYLO',sessionId:'S1',accessPointId:'AP1'}
  });
  let warmRequests=0;
  const originalSend2=comms2.send.bind(comms2);
  comms2.send=async (kind,payload,options)=>{
    if (kind===MessageKind.UI_DEFINITION_REQUIRED) warmRequests += 1;
    return originalSend2(kind,payload,options);
  };
  await comms2.connect(profile2.helloPayload({applicationId:'FLYLO',sessionId:'S1',accessPointId:'AP1'}));
  await waitFor(()=>renderer2.getInstance('answer'));
  assert.equal(warmRequests,0);
  assert.equal(definitions2.has('ASK_TRIGGER',1),true);
  assert.match(renderer2.getInstance('answer').slots.value,/Nothing has been added to your booking\./);
  await comms2.close();

  console.log('PASS ooRexx WireUIApplication <-> Queue Fabric gateway <-> JS runtime cold/warm full session');
} finally {
  await gateway.close();
  await port.close();
}
