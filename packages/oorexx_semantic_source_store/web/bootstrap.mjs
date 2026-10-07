const status = document.querySelector('#connection-status');
const mount = document.querySelector('#wire-ui-root');

function setStatus(message, state = '') {
  status.textContent = message;
  if (state) status.dataset.state = state;
  else delete status.dataset.state;
}

function showConnectionFailure(error) {
  mount.setAttribute('aria-busy', 'false');
  setStatus('Service unavailable', 'error');
  const existing = document.querySelector('#connection-detail');
  if (existing) existing.remove();
  const detail = document.createElement('div');
  detail.id = 'connection-detail';
  detail.className = 'connection-detail';
  detail.setAttribute('role', 'status');
  detail.textContent = error instanceof Error ? error.message : String(error);
  document.querySelector('.app-header')?.append(detail);
}

async function loadServiceDescriptor() {
  const endpoint = new URL('./service-descriptor', window.location.href);
  const response = await fetch(endpoint, {
    credentials: 'same-origin',
    headers: { Accept: 'application/json' }
  });
  if (!response.ok) {
    throw new Error(`Code Examiner service descriptor unavailable (${response.status}).`);
  }
  const descriptor = await response.json();
  if (!descriptor.websocketUrl || !descriptor.outboundQueue) {
    throw new Error('Incomplete Code Examiner service descriptor: websocketUrl and outboundQueue are required.');
  }
  if (descriptor.authenticationRequired !== true) {
    throw new Error('Code Examiner service descriptor must require authenticated principal context.');
  }
  const auth = descriptor.authentication ?? {};
  if (auth.principalSource !== 'verified-session') {
    throw new Error('Code Examiner principal source must be verified-session.');
  }
  if (auth.session !== 'opaque-bearer') {
    throw new Error('Code Examiner must use opaque-bearer session authority.');
  }
  const requiredStepUp = new Set([
    'WORK.ACCEPT', 'WORK.REFUSE', 'BRANCH.CLASSIFY',
    'BRANCH.PROTECT', 'BRANCH.CONFLICT.RESOLVE'
  ]);
  const suppliedStepUp = new Set(auth.privilegedStepUp ?? []);
  for (const action of requiredStepUp) {
    if (!suppliedStepUp.has(action)) {
      throw new Error(`Code Examiner service descriptor omits privileged step-up action ${action}.`);
    }
  }
  return descriptor;
}

async function startWireUI() {
  const {
    QueueFabricGatewayTransport,
    Comms,
    DefinitionRegistry,
    BrowserRenderer,
    WireUIRuntime,
    RenderProfileController,
    WireUIJourneyController,
    ObservationPlan
  } = await import('./vendor/alchemy-wire-ui/src/index.js');

  const config = await loadServiceDescriptor();
  const ownership = {
    applicationId: config.applicationId ?? 'SSC-CODE-EXAMINER',
    sessionId: config.sessionId ?? `SSC-HUMAN-${crypto.randomUUID()}`,
    accessPointId: config.accessPointId ?? 'WEB'
  };

  const transport = new QueueFabricGatewayTransport({
    url: config.websocketUrl,
    outboundQueue: config.outboundQueue,
    ownership,
    putResultMode: 'required'
  });

  const comms = new Comms({
    transport,
    source: config.source ?? 'SSC.CODE.EXAMINER.WEB',
    destination: config.outboundQueue
  });

  const definitions = new DefinitionRegistry();
  const renderer = new BrowserRenderer({ definitions, mount, document });
  const profile = new RenderProfileController({
    comms,
    definitions,
    renderer,
    siteId: 'SSC_CODE_EXAMINER',
    capabilities: {
      viewportClass: window.matchMedia('(max-width: 720px)').matches ? 'compact' : 'large',
      pointer: window.matchMedia('(pointer: coarse)').matches ? 'coarse' : 'fine',
      features: { dialog: 'HTMLDialogElement' in window }
    }
  });

  const runtime = new WireUIRuntime({
    comms,
    definitions,
    renderer,
    serverSemantic: true,
    renderProfile: profile,
    ownership
  });

  new WireUIJourneyController({ comms, runtime });
  new ObservationPlan({ comms });

  setStatus('Authenticating / connecting…');
  await comms.connect(profile.helloPayload(ownership));
  mount.setAttribute('aria-busy', 'false');
  setStatus('Connected', 'connected');
}

startWireUI().catch(showConnectionFailure);
