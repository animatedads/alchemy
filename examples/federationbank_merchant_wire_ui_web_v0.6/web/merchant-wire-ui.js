import { parseBootstrapSeed, loadWireUIBootstrap } from './bootstrap-config.js';
import { MerchantWorkspaceContextEcho } from './merchant-workspace-context.js';

const statusNode = document.getElementById('wire-ui-connection');
const mount = document.getElementById('wire-ui-root');
const configNode = document.getElementById('merchant-wire-ui-config');

function status(text, state = '') {
  statusNode.textContent = text;
  statusNode.dataset.state = state;
}

function requireConfig(config) {
  const required = ['moduleUrl', 'gatewayUrl', 'outboundQueue'];
  for (const name of required) if (!config?.[name]) throw new Error(`Merchant Wire UI bootstrap requires ${name}`);
  for (const name of ['applicationId', 'sessionId', 'accessPointId']) {
    if (!config?.ownership?.[name]) throw new Error(`Merchant Wire UI bootstrap requires ownership.${name}`);
  }
  return config;
}

async function boot() {
  const seed = parseBootstrapSeed(configNode?.textContent || '{}');
  const config = requireConfig(await loadWireUIBootstrap(seed));
  const api = await import(config.moduleUrl);
  const {
    QueueFabricGatewayTransport, Comms, DefinitionRegistry, BrowserRenderer,
    WireUIRuntime, RenderProfileController, WireUIJourneyController,
    ObservationPlan, LocalStorageDefinitionCache, MaterialController, MessageKind
  } = api;

  const transport = new QueueFabricGatewayTransport({
    url: config.gatewayUrl,
    outboundQueue: config.outboundQueue,
    ownership: config.ownership,
    putResultMode: 'required'
  });
  const comms = new Comms({
    transport,
    source: config.ownership.accessPointId,
    destination: config.outboundQueue
  });
  const workspaceContextEcho = new MerchantWorkspaceContextEcho({ comms, MessageKind }).install();
  const definitions = new DefinitionRegistry();
  const material = new MaterialController({ comms, document });
  const renderer = new BrowserRenderer({ definitions, mount, document });
  const definitionCache = new LocalStorageDefinitionCache({ storage: globalThis.localStorage });
  const profile = new RenderProfileController({
    comms,
    definitions,
    definitionCache,
    renderer,
    siteId: config.siteId ?? 'FEDERATIONBANK_MERCHANT'
  });
  const runtime = new WireUIRuntime({
    comms,
    definitions,
    renderer,
    serverSemantic: true,
    renderProfile: profile,
    ownership: config.ownership
  });
  new WireUIJourneyController({ comms, runtime });
  new ObservationPlan({ comms });

  comms.onState((event) => {
    if (event.type === 'connected') status('Live', 'live');
    else if (event.type === 'closed') status('Disconnected', 'closed');
    else if (event.type === 'sequence-gap') status('Synchronising…', 'sync');
    else if (event.type === 'inbound-handler-error') status('Resynchronising…', 'error');
  });

  await comms.connect(profile.helloPayload({ accessPointId: config.ownership.accessPointId }));
  globalThis.__federationBankMerchantWireUI = Object.freeze({ comms, runtime, renderer, definitions, profile, material, workspaceContextEcho });
}

boot().catch((error) => {
  console.error('FederationBank Merchant Wire UI bootstrap failed', error);
  status('Unable to connect', 'error');
  mount.replaceChildren();
  const panel = document.createElement('section');
  panel.className = 'wire-ui-bootstrap-error';
  panel.textContent = 'The Merchant Banking workspace could not establish this session. Please reload or contact support.';
  mount.appendChild(panel);
});
