import {
  BrowserRenderer, Comms, DefinitionRegistry, MaterialController,
  ObservationPlan, QueueFabricGatewayTransport, RenderProfileController,
  WireUIJourneyController, WireUIRuntime
} from './vendor/alchemy-wire-ui/src/index.js';


const RID_JOURNEY_DEFINITIONS={
  MORTGAGE:[
    ['APPLICATION','Application','Case opened and application prepared'],
    ['UNDERWRITING','Underwriting','Federation reviews the mortgage application'],
    ['DECISION','Decision','Authoritative lending decision'],
    ['OFFER','Offer','Mortgage offer issued'],
    ['SIGNING','Digital signing','Customer signs the exact sealed offer'],
    ['COMPLETE','Completion','Provider completes the mortgage journey']
  ],
  INSURANCE:[
    ['APPLICATION','Application','Insurance risk and customer details captured'],
    ['UNDERWRITING','Underwriting','All Japan evaluates the submitted risk'],
    ['QUOTE','Quote','Authoritative insurance quote available'],
    ['SIGNING','Digital signing','Customer signs the exact quote / contract material'],
    ['BOUND','Bound','All Japan policy authority confirms cover'],
    ['COMPLETE','Complete','Distribution case completed']
  ],
  INVESTMENT:[
    ['DISCOVERY','Discovery','Objectives and customer needs captured'],
    ['SUITABILITY','Suitability','Advice / appropriateness evidence completed'],
    ['APPROVAL','Product approval','Authoritative product decision available'],
    ['INSTRUCTION','Instruction','Customer instruction / signature captured'],
    ['EXECUTION','Execution','Investment provider processes the instruction'],
    ['COMPLETE','Complete','Distribution case completed']
  ]
};

export function buildRIDJourneyModel(input={}){
  const family=String(input.productFamily??'MORTGAGE').toUpperCase();
  const provider=String(input.providerStatus??'').toUpperCase();
  const workflow=String(input.workflowState??'').toUpperCase();
  const work=String(input.workStatus??'').toUpperCase();
  const completion=String(input.completionMode??'').toUpperCase();
  const attention=String(input.attentionState??'').toUpperCase();
  const failed=provider==='DECLINED'||provider==='REJECTED';
  const defs=RID_JOURNEY_DEFINITIONS[family]??RID_JOURNEY_DEFINITIONS.MORTGAGE;
  let key=defs[0][0];
  if(family==='MORTGAGE'){
    if(provider==='COMPLETED') key='COMPLETE';
    else if(provider==='OFFERED') key=(completion==='SIGNATURE'&&work!=='COMPLETE')?'SIGNING':(work==='COMPLETE'?'COMPLETE':'OFFER');
    else if(['APPROVED','DECLINED','REJECTED'].includes(provider)) key='DECISION';
    else if(['RECEIVED','DOCUMENT_REVIEW','UNDERWRITING','DOCUMENTS_REQUIRED','PROCESSING'].includes(provider)) key='UNDERWRITING';
    else if(['SUBMISSION_REQUESTED','APPLICATION_READY','RECOMMENDED','DISCOVERY','OPEN'].includes(workflow)) key='APPLICATION';
  }else if(family==='INSURANCE'){
    if(provider==='COMPLETED') key='COMPLETE';
    else if(provider==='BOUND') key='BOUND';
    else if(provider==='QUOTED') key=(completion==='SIGNATURE'&&work!=='COMPLETE')?'SIGNING':(work==='COMPLETE'?'BOUND':'QUOTE');
    else if(['APPROVED','UNDERWRITER_REVIEW','UNDERWRITING','DOCUMENT_REVIEW','DOCUMENTS_REQUIRED','RECEIVED','PROCESSING','DECLINED','REJECTED'].includes(provider)) key='UNDERWRITING';
    else key='APPLICATION';
  }else if(family==='INVESTMENT'){
    if(['COMPLETED','SETTLED'].includes(provider)) key='COMPLETE';
    else if(['EXECUTED','PROCESSING'].includes(provider)) key='EXECUTION';
    else if(completion==='SIGNATURE'&&work!=='COMPLETE') key='INSTRUCTION';
    else if(['APPROVED','DECLINED','REJECTED','RECEIVED'].includes(provider)) key='APPROVAL';
    else if(['RECOMMENDED','APPLICATION_READY','SUBMISSION_REQUESTED'].includes(workflow)) key='SUITABILITY';
    else key='DISCOVERY';
  }
  let current=Math.max(0,defs.findIndex(([k])=>k===key));
  const stages=defs.map(([stageKey,label,hint],i)=>({
    key:stageKey,label,hint,
    state:i<current?'complete':i===current?(failed?'failed':'current'):'upcoming'
  }));
  const responsibility=attention==='OVERDUE'?'Overdue intermediary action':attention==='ACTION_REQUIRED'?'Intermediary action required':attention==='WAITING_PROVIDER'?'Waiting on provider':work==='COMPLETE'?'No intermediary action required':'Case progressing';
  return {family,provider,workflow,failed,current,stages,responsibility};
}

export class RIDStatefulBrowserRenderer extends BrowserRenderer {
  constructor(options){ super(options); this.state=new Map(); this.changeSink=null; }
  onChange(fn){ this.changeSink=fn; return this; }
  reset(){ super.reset(); this.state.clear(); this.#changed(); }
  createInstance(instance){
    this.state.set(String(instance.instanceId),{...(instance.slots??{})});
    super.createInstance(instance); this.#changed();
  }
  setSlot(instanceId,slot,value){
    const id=String(instanceId); const current=this.state.get(id)??{}; current[slot]=value; this.state.set(id,current);
    super.setSlot(instanceId,slot,value); this.#changed();
  }
  destroyInstance(instanceId){ this.state.delete(String(instanceId)); super.destroyInstance(instanceId); this.#changed(); }
  slots(instanceId){ return {...(this.state.get(String(instanceId))??{})}; }
  #changed(){ this.changeSink?.(); }
}

export class RIDBrowserController {
  constructor({runtime,renderer,actionsMount,statusMount,controlsMount,document=globalThis.document}){
    this.runtime=runtime; this.renderer=renderer; this.actionsMount=actionsMount; this.statusMount=statusMount; this.controlsMount=controlsMount; this.document=document;
    this.boundRows=new WeakSet(); this.pending=false; this.lastError='';
    renderer.onChange(()=>this.schedule());
  }
  schedule(){ if(this.pending)return; this.pending=true; queueMicrotask(()=>{this.pending=false;this.renderControls();}); }
  workspaceContext(caseId){
    const t=this.renderer.slots('case-table');
    return {
      workspaceRef:'RID.CASES', queryRevision:Number(t.queryRevision??0), scopeRevision:Number(t.scopeRevision??0),
      orderRevision:Number(t.orderRevision??0), selectionRevision:Number(t.selectionRevision??0), resultRevision:Number(t.resultRevision??0), resultQueryRevision:Number(t.resultQueryRevision??0), resultScopeRevision:Number(t.resultScopeRevision??0), resultOrderRevision:Number(t.resultOrderRevision??0), selectedIds:[caseId]
    };
  }
  async selectCase(caseId){
    const detail=this.renderer.slots('case-detail');
    if(detail.visible && detail.caseId===caseId) return;
    const t=this.renderer.slots('case-table'); const before=Number(t.selectionRevision??0); const scope=Number(t.scopeRevision??0);
    await this.runtime.sendSemanticAction('CASES.SELECT',{instanceId:'case-query',detail:{selectedIds:[caseId],scopeRevision:scope}});
    await this.waitUntil(()=>{const now=this.renderer.slots('case-table');const d=this.renderer.slots('case-detail');return Number(now.selectionRevision??0)>before&&d.caseId===caseId&&Boolean(d.visible);},'case selection');
  }
  async refresh(){
    const before=Number(this.renderer.slots('case-table').windowRevision??0);
    await this.runtime.sendSemanticAction('DASHBOARD.REFRESH',{instanceId:'case-query',detail:{}});
    await this.waitUntil(()=>Number(this.renderer.slots('case-table').windowRevision??0)>before,'dashboard refresh');
  }
  async filter(filterRef,value){
    const ref=String(filterRef??'').toLowerCase(); const target=String(value??'ALL').toUpperCase();
    const beforeSlots=this.renderer.slots('case-table'); const beforeScope=Number(beforeSlots.scopeRevision??0); const beforeFilters=this.parseFilterRef(beforeSlots.filterRef??'');
    const current=String(beforeFilters[ref]??'ALL').toUpperCase(); if(current===target) return;
    await this.runtime.sendSemanticAction('CASES.FILTER',{instanceId:'case-query',detail:{filterRef:ref,value:target}});
    await this.waitUntil(()=>{const t=this.renderer.slots('case-table');const filters=this.parseFilterRef(t.filterRef??'');const actual=String(filters[ref]??'ALL').toUpperCase();return actual===target&&Number(t.scopeRevision??0)>beforeScope;},`filter ${ref}`);
  }
  async sort(sortRef,direction='DESC'){
    const ref=String(sortRef??'PRIORITY').toUpperCase(); const dir=String(direction??'DESC').toUpperCase();
    const before=this.renderer.slots('case-table'); const beforeOrder=Number(before.orderRevision??0); if(String(before.sortRef??'').toUpperCase()===`${ref}:${dir}`) return;
    await this.runtime.sendSemanticAction('CASES.SORT',{instanceId:'case-query',detail:{sortRef:ref,direction:dir}});
    await this.waitUntil(()=>{const t=this.renderer.slots('case-table');return String(t.sortRef??'').toUpperCase()===`${ref}:${dir}`&&Number(t.orderRevision??0)>beforeOrder;},`sort ${ref}`);
  }
  async waitUntil(predicate,label,timeoutMs=6000){
    const deadline=Date.now()+timeoutMs;
    while(Date.now()<deadline){if(predicate())return;await new Promise(resolve=>setTimeout(resolve,10));}
    throw new Error(`Timed out waiting for authoritative ${label} state`);
  }
  async acknowledge(caseId){
    await this.runtime.sendSemanticAction('WORK.ACK',{instanceId:'case-detail',detail:{caseId,workspaceContext:this.workspaceContext(caseId)}});
  }
  async prepareSignature(caseId,{requirementId,authenticationRef,consentRef}){
    await this.runtime.sendSemanticAction('SIGNATURE.PREPARE',{instanceId:'signing',detail:{caseId,requirementId,authenticationRef,consentRef,workspaceContext:this.workspaceContext(caseId)}});
  }
  async submitSignature(caseId,{challengeId,keyId,signatureHex,evidenceRef}){
    await this.runtime.sendSemanticAction('SIGNATURE.SUBMIT',{instanceId:'signing',detail:{caseId,challengeId,keyId,signatureHex,evidenceRef,workspaceContext:this.workspaceContext(caseId)}});
  }
  renderControls(){
    this.renderWorkspaceControls();
    for(const [id,live] of this.renderer.instances){
      const slots=this.renderer.slots(id);
      if(slots.caseId && id===slots.caseId){
        live.root.classList?.add?.('rid-clickable-case');
        live.root.setAttribute?.('data-rid-status',String(slots.providerStatus??''));
        live.root.setAttribute?.('data-rid-attention',String(slots.attentionState??''));
        live.root.setAttribute?.('data-rid-product',String(slots.productFamily??''));
        live.root.setAttribute?.('data-rid-priority',String(slots.priority??''));
        live.root.setAttribute?.('aria-label',`Open ${slots.productFamily??''} case ${slots.caseId}: ${slots.providerStatus??''}; ${slots.nextAction??''}`);
        if(!this.boundRows.has(live.root)){
          this.boundRows.add(live.root);
          live.root.addEventListener('click',()=>this.selectCase(this.renderer.slots(id).caseId).catch(e=>this.showError(e)));
        }
      }
      if(String(id).startsWith('RID-TL-')){
        live.root.classList?.add?.('rid-timeline-event');
        live.root.setAttribute?.('data-rid-kind',String(slots.kind??''));
        live.root.setAttribute?.('data-rid-status',String(slots.status??''));
      }
    }
    const detail=this.renderer.slots('case-detail'); const signing=this.renderer.slots('signing');
    const rowContext=detail.caseId?this.renderer.slots(detail.caseId):{}; const caseView={...rowContext,...detail};
    if(this.statusMount){
      const summary=this.renderer.slots('summary');
      this.statusMount.innerHTML=`<span></span>${summary.actionRequired??0} action · ${summary.overdue??0} overdue · ${summary.waitingProvider??0} waiting`; this.statusMount.setAttribute?.('data-state','connected');
    }
    if(!this.actionsMount)return;
    this.actionsMount.replaceChildren();
    if(!detail.visible || !detail.caseId) return;
    const statusLabel=String(caseView.providerStatus??'').replaceAll('_',' ');
    const header=this.document.createElement('div'); header.className='rid-dossier-header';
    const titleWrap=this.document.createElement('div');
    const eyebrow=this.document.createElement('p'); eyebrow.className='rid-eyebrow'; eyebrow.textContent=String(caseView.productFamily??'CASE');
    const title=this.document.createElement('h2'); title.textContent=`Case ${detail.caseId}`; titleWrap.append(eyebrow,title);
    const badge=this.document.createElement('span'); badge.className='rid-status-badge'; badge.setAttribute?.('data-status',String(caseView.providerStatus??'')); badge.textContent=statusLabel||'OPEN';
    header.append(titleWrap,badge); this.actionsMount.appendChild(header);
    const state=this.document.createElement('div'); state.className='rid-provider-state'; state.setAttribute?.('data-attention',String(caseView.attentionState??''));
    const next=this.document.createElement('strong'); next.textContent=String(caseView.nextAction??'No intermediary action required').replaceAll('_',' ');
    const journey=buildRIDJourneyModel(caseView);
    const meta=this.document.createElement('span'); meta.textContent=`${journey.responsibility} · work ${detail.workStatus??'—'} · priority ${caseView.priority??'—'}`;
    state.append(next,meta); this.actionsMount.appendChild(state);
    const facts=this.document.createElement('dl'); facts.className='rid-case-facts';
    const fact=(label,value)=>{const pair=this.document.createElement('div');pair.className='rid-fact-pair';const dt=this.document.createElement('dt');dt.textContent=label;const dd=this.document.createElement('dd');dd.textContent=value||'—';pair.append(dt,dd);facts.appendChild(pair)};
    fact('Customer',detail.subjectRef); fact('Product',detail.productRefId); fact('Workflow',String(caseView.workflowState??'').replaceAll('_',' ')); fact('Waiting on',caseView.waitingOn); fact('Evidence',detail.completionEvidenceRef);
    this.actionsMount.appendChild(facts);
    this.renderJourney(caseView);
    this.renderDocumentSummary(signing);
    this.renderTimeline(detail.caseId);
    const actionZone=this.document.createElement('section'); actionZone.className='rid-action-zone';
    const actionHead=this.document.createElement('div'); actionHead.className='rid-subheading'; actionHead.textContent='Next intermediary action'; actionZone.appendChild(actionHead);
    const actionable=detail.workStatus==='OPEN'||detail.workStatus==='OVERDUE';
    let hasAction=false;
    if(actionable && detail.completionMode==='ACK' && detail.canAcknowledge){
      hasAction=true; actionZone.appendChild(this.button('Acknowledge action',()=>this.acknowledge(detail.caseId)));
    }
    if(actionable && detail.completionMode==='SIGNATURE' && (signing.canPrepareSignature||signing.canSubmitSignature)){
      hasAction=true;
      if(!signing.challengeId && signing.canPrepareSignature){
        const req=this.input('requirementId','Signature requirement',signing.requirementId||'CUSTOMER-SIGN');
        const auth=this.input('authenticationRef','Authentication evidence','AUTH:PASSKEY');
        const consent=this.input('consentRef','Consent evidence','CONSENT:DIGITAL');
        actionZone.append(req.wrap,auth.wrap,consent.wrap,this.button('Prepare digital signature',()=>this.prepareSignature(detail.caseId,{requirementId:req.input.value,authenticationRef:auth.input.value,consentRef:consent.input.value})));
      } else if(signing.canSubmitSignature) {
        const notice=this.document.createElement('p'); notice.className='rid-signing-challenge'; notice.textContent=`Sign exact challenge ${signing.challengeId} for ${signing.signerRef} (${signing.purpose}).`; actionZone.appendChild(notice);
        const key=this.input('keyId','Signing key','CUSTOMER-W-KEY'); const sig=this.input('signatureHex','Signature',''); const ev=this.input('evidenceRef','Device evidence','DEVICE:WEBAUTHN');
        actionZone.append(key.wrap,sig.wrap,ev.wrap,this.button('Submit signature',()=>this.submitSignature(detail.caseId,{challengeId:signing.challengeId,keyId:key.input.value,signatureHex:sig.input.value,evidenceRef:ev.input.value})));
      }
    }
    if(!hasAction){const none=this.document.createElement('p');none.className='rid-action-zone-empty';none.textContent=journey.responsibility==='Waiting on provider'?'No intermediary action is required until the provider publishes the next authoritative event.':'There is no outstanding intermediary action for this case.';actionZone.appendChild(none)}
    this.actionsMount.appendChild(actionZone);
  }
  renderJourney(detail){
    const model=buildRIDJourneyModel(detail);
    const section=this.document.createElement('section'); section.className='rid-case-journey'; section.setAttribute?.('data-product',model.family);
    const head=this.document.createElement('div'); head.className='rid-journey-heading';
    const title=this.document.createElement('div'); const eye=this.document.createElement('div'); eye.className='rid-subheading'; eye.textContent='Case journey';
    const summary=this.document.createElement('strong'); summary.textContent=model.responsibility; title.append(eye,summary);
    const product=this.document.createElement('span'); product.className='rid-product-chip'; product.textContent=model.family; head.append(title,product); section.appendChild(head);
    const rail=this.document.createElement('ol'); rail.className='rid-journey-rail';
    for(const stage of model.stages){
      const item=this.document.createElement('li'); item.className=`rid-journey-stage is-${stage.state}`; item.setAttribute?.('data-stage',stage.key);
      const marker=this.document.createElement('span'); marker.className='rid-journey-marker'; marker.textContent=stage.state==='complete'?'✓':stage.state==='failed'?'!':'';
      const copy=this.document.createElement('div'); const label=this.document.createElement('strong'); label.textContent=stage.label; const hint=this.document.createElement('span'); hint.textContent=stage.hint; copy.append(label,hint); item.append(marker,copy); rail.appendChild(item);
    }
    section.appendChild(rail); this.actionsMount.appendChild(section);
  }
  renderDocumentSummary(signing){
    if(!signing?.envelopeId)return;
    const section=this.document.createElement('section'); section.className='rid-document-summary';
    const title=this.document.createElement('div'); title.className='rid-subheading'; title.textContent='Signing document'; section.appendChild(title);
    const name=this.document.createElement('strong'); name.textContent=`${String(signing.documentType??'Document').replaceAll('_',' ')} · v${signing.documentVersion??'—'}`; section.appendChild(name);
    const semantic=this.document.createElement('p'); semantic.textContent=signing.documentSemanticIdentity??''; section.appendChild(semantic);
    const refs=this.document.createElement('div'); refs.className='rid-document-refs';
    const ref=(label,value)=>{const n=this.document.createElement('span');n.textContent=`${label}: ${value||'—'}`;refs.appendChild(n)};
    ref('Storage',signing.storageRef); ref('Durable medium',signing.durableMediumRef); ref(signing.digestAlgorithm||'Digest',signing.contentDigest); section.appendChild(refs);
    this.actionsMount.appendChild(section);
  }
  renderTimeline(caseId){
    const entries=[];
    for(const [id,slots] of this.renderer.state){
      if(!String(id).startsWith('RID-TL-'))continue;
      entries.push({...slots,__id:id});
    }
    if(!entries.length)return;
    entries.sort((a,b)=>String(b.occurredAt??'').localeCompare(String(a.occurredAt??''))||String(b.timelineId??b.__id).localeCompare(String(a.timelineId??a.__id)));
    const section=this.document.createElement('section'); section.className='rid-live-timeline';
    const head=this.document.createElement('div'); head.className='rid-subheading'; head.textContent='Case timeline'; section.appendChild(head);
    for(const item of entries.slice(0,7)){
      const event=this.document.createElement('div'); event.className='rid-live-event'; event.setAttribute?.('data-kind',String(item.kind??'')); event.setAttribute?.('data-status',String(item.status??''));
      const rail=this.document.createElement('span'); rail.className='rid-live-event-rail';
      const body=this.document.createElement('div');
      const top=this.document.createElement('div'); top.className='rid-live-event-top';
      const label=this.document.createElement('strong'); label.textContent=String(item.label??item.status??item.kind??'Case event').replaceAll('_',' ');
      const time=this.document.createElement('time'); time.textContent=item.occurredAt??''; top.append(label,time); body.appendChild(top);
      const meta=this.document.createElement('p'); meta.textContent=[item.kind,item.status,item.actorRef,item.evidenceRef].filter(Boolean).join(' · '); body.appendChild(meta);
      event.append(rail,body); section.appendChild(event);
    }
    this.actionsMount.appendChild(section);
  }
  renderWorkspaceControls(){
    if(!this.controlsMount)return;
    const t=this.renderer.slots('case-table'); const filtersNow=this.parseFilterRef(t.filterRef??''); const [sortNow,dirNow]=String(t.sortRef??'PRIORITY:DESC').split(':'); this.controlsMount.replaceChildren();
    const title=this.document.createElement('strong'); title.textContent='Worklist'; this.controlsMount.appendChild(title);
    const filters=[
      ['attention_state','Attention',filtersNow.attention_state??'ALL',['ALL','OVERDUE','ACTION_REQUIRED','WAITING_PROVIDER','COMPLETE']],
      ['product_family','Product',filtersNow.product_family??'ALL',['ALL','MORTGAGE','INVESTMENT','INSURANCE']],
      ['provider_status','Provider status',filtersNow.provider_status??'ALL',['ALL','RECEIVED','UNDERWRITING','DOCUMENTS_REQUIRED','APPROVED','OFFERED','QUOTED','DECLINED','REJECTED','BOUND','COMPLETED']]
    ];
    for(const [ref,label,value,values] of filters){
      const control=this.select(label,value,values); control.select.addEventListener('change',()=>this.filter(ref,control.select.value).catch(e=>this.showError(e))); this.controlsMount.appendChild(control.wrap);
    }
    const sort=this.select('Sort',sortNow||'PRIORITY',['PRIORITY','ATTENTION','CASE_ID','PROVIDER_STATUS','PRODUCT_FAMILY']);
    sort.select.addEventListener('change',()=>this.sort(sort.select.value,dir.select.value||'DESC').catch(e=>this.showError(e))); this.controlsMount.appendChild(sort.wrap);
    const dir=this.select('Direction',dirNow||'DESC',['DESC','ASC']); dir.select.addEventListener('change',()=>this.sort(sort.select.value,dir.select.value).catch(e=>this.showError(e))); this.controlsMount.appendChild(dir.wrap);
    this.controlsMount.appendChild(this.button('Refresh',()=>this.refresh()));
  }
  parseFilterRef(text){ const out={}; for(const item of String(text||'').split(';')){ if(!item)continue; const i=item.indexOf('='); if(i>0)out[item.slice(0,i)]=item.slice(i+1); } return out; }
  input(name,label,value){ const wrap=this.document.createElement('label'); wrap.className='rid-control'; wrap.textContent=label; const input=this.document.createElement('input'); input.name=name; input.value=value; wrap.appendChild(input); return {wrap,input}; }
  select(label,value,values){ const wrap=this.document.createElement('label'); wrap.className='rid-control'; wrap.textContent=label; const select=this.document.createElement('select'); for(const v of values){const o=this.document.createElement('option');o.value=v;o.textContent=v.replaceAll('_',' ');if(v===value)o.selected=true;select.appendChild(o)} select.value=value; wrap.appendChild(select); return {wrap,select}; }
  button(label,handler){ const b=this.document.createElement('button'); b.type='button'; b.className='rid-primary'; b.textContent=label; b.addEventListener('click',()=>Promise.resolve(handler()).catch(e=>this.showError(e))); return b; }
  showError(error){ this.lastError=String(error?.message??error); if(this.statusMount)this.statusMount.textContent=this.lastError; }
}

export async function bootRIDBrowser(config={}){
  const applicationId=config.applicationId??'RID-APP'; const sessionId=config.sessionId??crypto.randomUUID(); const accessPointId=config.accessPointId??'WEB';
  const gatewayUrl=config.gatewayUrl; if(!gatewayUrl)throw new Error('gatewayUrl is required');
  const outboundQueue=config.outboundQueue??`WIREUI.IN.${accessPointId}`;
  const ownership={applicationId,sessionId,accessPointId};
  const transport=new QueueFabricGatewayTransport({url:gatewayUrl,outboundQueue,ownership,putResultMode:'required'});
  const comms=new Comms({transport,source:`browser:${sessionId}`,destination:`server:${applicationId}`});
  const definitions=new DefinitionRegistry(); const mount=document.querySelector(config.mount??'#rid-app');
  const renderer=new RIDStatefulBrowserRenderer({definitions,mount,document});
  const material=new MaterialController({comms,document});
  const profile=new RenderProfileController({comms,definitions,renderer,siteId:'FEDERATION_RID'});
  const runtime=new WireUIRuntime({comms,definitions,renderer,serverSemantic:true,renderProfile:profile,ownership});
  new WireUIJourneyController({comms,runtime}); new ObservationPlan({comms});
  const controller=new RIDBrowserController({runtime,renderer,actionsMount:document.querySelector(config.actionsMount??'#rid-actions'),controlsMount:document.querySelector(config.controlsMount??'#rid-controls'),statusMount:document.querySelector(config.statusMount??'#rid-connection'),document});
  comms.onState(e=>{ if(e.type==='connected'&&controller.statusMount){controller.statusMount.innerHTML='<span></span>Connected · live';controller.statusMount.setAttribute?.('data-state','connected');} });
  await comms.connect(profile.helloPayload({accessPointId}));
  return {transport,comms,definitions,renderer,runtime,controller,material,profile};
}

if(typeof window!=='undefined' && window.RID_BOOT_CONFIG){ bootRIDBrowser(window.RID_BOOT_CONFIG).catch(e=>{ const n=document.querySelector('#rid-connection'); if(n)n.textContent=String(e.message??e); }); }
