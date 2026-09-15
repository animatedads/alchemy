function parseDefinitionKey(value='') {
  const at=String(value).lastIndexOf('@');
  if(at<=0) return null;
  const version=Number(String(value).slice(at+1));
  if(!Number.isSafeInteger(version)||version<1) return null;
  return {id:String(value).slice(0,at),version};
}

export function viewportClassForWidth(width) {
  const n=Number(width);
  if(!Number.isFinite(n)) return 'DEFAULT';
  if(n<640) return 'SMALL';
  if(n<1024) return 'MEDIUM';
  return 'LARGE';
}

export function stateFromJourneyPlan(plan={},applicationId='') {
  const planId=String(plan.planId??'');
  const prefix=applicationId ? `${applicationId}:` : '';
  let rest=prefix && planId.startsWith(prefix) ? planId.slice(prefix.length) : planId;
  const last=rest.lastIndexOf(':');
  if(last>0) rest=rest.slice(0,last);
  return rest || null;
}

export function selectCompositionHint(definition,{stateId=null,viewportClass='DEFAULT'}={}) {
  const hints=definition?.semantic?.metadata?.compositionHints;
  if(!Array.isArray(hints)) return null;
  const state=hints.filter((hint)=>!stateId || hint?.stateId===stateId);
  if(!state.length) return null;
  const exact=state.find((hint)=>String(hint?.placement?.viewportClass??'DEFAULT').toUpperCase()===String(viewportClass).toUpperCase());
  return exact ?? state.find((hint)=>String(hint?.placement?.viewportClass??'DEFAULT').toUpperCase()==='DEFAULT') ?? state[0];
}

export function placementPresentation(hint) {
  const p=hint?.placement??{};
  const span=Math.max(1,Math.min(12,Number(p.span??12)||12));
  const rowSpan=Math.max(1,Number(p.rowSpan??1)||1);
  const align=String(p.align??'STRETCH').toUpperCase();
  return Object.freeze({
    layoutModel:String(hint?.layoutModel??'GRID12').toUpperCase(),
    region:String(p.region??'main'),
    order:Number(p.order??0)||0,
    span,
    rowSpan,
    alignSelf:({START:'start',CENTER:'center',END:'end',STRETCH:'stretch'})[align]??'stretch'
  });
}

export function parseCollectionItemText(text='') {
  const out=Object.create(null);
  for(const part of String(text).split(' · ')) {
    const at=part.indexOf(':');
    if(at<=0) continue;
    out[part.slice(0,at).trim()]=part.slice(at+1).trim();
  }
  return out;
}

export function nextAlignment(current='STRETCH') {
  const values=['STRETCH','START','CENTER','END'];
  const value=String(current??'STRETCH').toUpperCase();
  const at=values.indexOf(value);
  return values[(at+1+values.length)%values.length];
}

export function parseFlowLayoutSignature(value='') {
  if(!value) return [];
  return String(value).split('|').filter(Boolean).map((part)=>{
    const [region='main',span='12',elementId='',align='STRETCH']=part.split('~');
    return Object.freeze({region,span:Math.max(1,Math.min(12,Number(span)||12)),elementId,align:String(align).toUpperCase()});
  });
}

export function semanticRegionList(observed=[]) {
  return [...new Set([...observed,'header','sidebar','main','secondary','footer'].map((v)=>String(v??'').trim()).filter(Boolean))];
}

export function nextRegion(current, observed=[]) {
  const values=semanticRegionList(observed);
  if(!values.length) return 'main';
  const at=values.indexOf(String(current??''));
  return values[(at+1+values.length)%values.length];
}

export function resizedSpan(startSpan,deltaPx,totalWidth) {
  const initial=Math.max(1,Math.min(12,Number(startSpan)||1));
  const width=Number(totalWidth);
  const delta=Number(deltaPx);
  if(!Number.isFinite(width)||width<=0||!Number.isFinite(delta)) return initial;
  const columns=Math.round(delta/(width/12));
  return Math.max(1,Math.min(12,initial+columns));
}

// Stable browser placement for the Studio's structural regions.  These line
// numbers are only a presentation of the authored GRID12 composition: the
// semantic region/span values remain the source of truth.  Using explicit
// grid lines avoids relying on auto-placement for the three-column DESIGN
// workspace and also makes Firefox/Chromium agree when live roots are
// re-parented into presentation-only region stacks.
export function studioRegionGridColumn(region,span=12) {
  const name=String(region??'').trim().toLowerCase();
  const fixed={header:'1 / 13',nav:'1 / 13',library:'1 / 4',canvas:'4 / 10',inspector:'10 / 13',flow:'1 / 13'};
  if(fixed[name]) return fixed[name];
  const width=Math.max(1,Math.min(12,Number(span)||12));
  return `auto / span ${width}`;
}

// DESIGN is Studio chrome, not the target composition. Give those chrome
// regions explicit rows as well as columns so browser grid auto-placement can
// never move FLOW beside CANVAS or compress the workbench into early tracks.
// Other Studio states retain authored-span auto placement.
export function studioRegionGridRow(region,stateId='') {
  const state=String(stateId??'').toUpperCase();
  const name=String(region??'').trim().toLowerCase();
  const fixed={
    DESIGN:{header:'1',nav:'2',library:'3',canvas:'3',inspector:'3',flow:'4'},
    SOURCE:{header:'1',nav:'2','source-list':'3','source-detail':'3'},
    COMPONENTS:{header:'1',nav:'2',catalogue:'3','component-editor':'3','element-editor':'3','projection-editor':'3'},
    MATERIALS:{header:'1',nav:'2',catalogue:'3','material-editor':'3',preview:'3'},
    FLOW:{header:'1',nav:'2',catalogue:'3',flow:'3','journey-editor':'4','condition-editor':'4','policy-editor':'4','experiment-editor':'5',preview:'5'},
    PUBLISH:{header:'1',nav:'2',catalogue:'3',preview:'3',publish:'3'}
  };
  return fixed[state]?.[name]??'auto';
}

export function studioRegionGridArea(region,stateId='') {
  const state=String(stateId??'').toUpperCase();
  const name=String(region??'').trim().toLowerCase();
  const allowed={
    DESIGN:['header','nav','library','canvas','inspector','flow'],
    SOURCE:['header','nav','source-list','source-detail'],
    COMPONENTS:['header','nav','catalogue','component-editor','element-editor','projection-editor'],
    MATERIALS:['header','nav','catalogue','material-editor','preview'],
    FLOW:['header','nav','catalogue','flow','journey-editor','condition-editor','policy-editor','experiment-editor','preview'],
    PUBLISH:['header','nav','catalogue','preview','publish']
  };
  return allowed[state]?.includes(name)?name:'';
}

function safeStop(event) { event?.preventDefault?.(); event?.stopPropagation?.(); }

export class BuilderCompositionController {
  constructor({comms,runtime,renderer,definitions,mount,journeyController,ownership={},window=globalThis.window,MutationObserverImpl=globalThis.MutationObserver}) {
    this.comms=comms; this.runtime=runtime; this.renderer=renderer; this.definitions=definitions; this.mount=mount; this.journeyController=journeyController; this.ownership=ownership;
    this.window=window; this.MutationObserverImpl=MutationObserverImpl; this.stateId=null;
    this.dragSourceId=null; this.dragSourceInfo=null; this.selectedPlacementId=null; this.selectedPlacementInfo=null; this.selectedLibraryId=null; this.selectedFlowId=null; this.targetStateId=null;
    this.disposers=[]; this.observer=null; this.resizeSession=null;
  }

  start() {
    if(this.journeyController?.onState) this.disposers.push(this.journeyController.onState((event)=>{
      if(event?.type!=='journey-plan-installed') return;
      this.stateId=stateFromJourneyPlan(event.plan,this.ownership.applicationId??''); this.apply();
    }));
    if(this.MutationObserverImpl && this.mount) {
      this.observer=new this.MutationObserverImpl(()=>this.apply());
      this.observer.observe(this.mount,{childList:true,subtree:true});
    }
    if(this.window?.addEventListener) {
      const resize=()=>this.apply(); this.window.addEventListener('resize',resize); this.disposers.push(()=>this.window.removeEventListener('resize',resize));
    }
    this.apply(); return this;
  }

  stop() {
    this.#endResize(null,false);
    this.observer?.disconnect?.();
    for(const dispose of this.disposers.splice(0)) dispose?.();
  }

  apply() {
    if(!this.mount?.querySelectorAll) return;
    const viewportClass=viewportClassForWidth(this.window?.innerWidth);
    const roots=[...this.mount.querySelectorAll('[data-wire-definition]')];
    let shell=null;
    for(const node of roots) {
      const parsed=parseDefinitionKey(node.getAttribute('data-wire-definition')); if(!parsed) continue;
      const definition=this.definitions?.get?.(parsed.id,parsed.version); if(!definition) continue;
      if(parsed.id==='WUIB_SHELL') { shell=node; node.classList?.remove?.('wui-composition-inactive'); continue; }
      const hint=selectCompositionHint(definition,{stateId:this.stateId,viewportClass});
      if(!hint) { this.#clearPlacement(node); if(this.stateId) node.classList?.add?.('wui-composition-inactive'); else node.classList?.remove?.('wui-composition-inactive'); continue; }
      node.classList?.remove?.('wui-composition-inactive');
      const view=placementPresentation(hint); this.#applyPlacement(node,view);
    }
    if(shell) { shell.classList?.add?.('wui-builder-composition-grid'); shell.dataset.wireCompositionState=this.stateId??''; shell.dataset.wireViewportClass=viewportClass; this.#arrangeStudioRegions(shell); }
    this.#enhanceCanvas(); this.#enhanceArtifactLibrary(); this.#enhanceFlowMap(); this.#enhanceToolNav(); this.#enhanceInspector();
  }

  #applyPlacement(node,view) {
    node.dataset.wireRegion=view.region; node.dataset.wireLayoutModel=view.layoutModel; node.dataset.wireSpan=String(view.span); node.dataset.wireOrder=String(view.order);
    node.style.order=String(view.order); node.style.gridColumn=`span ${view.span}`; node.style.gridRow=`span ${view.rowSpan}`; node.style.alignSelf=view.alignSelf;
  }
  #clearPlacement(node) {
    if(node?.dataset){ delete node.dataset.wireRegion; delete node.dataset.wireLayoutModel; delete node.dataset.wireSpan; delete node.dataset.wireOrder; }
    if(node?.style){ node.style.order=''; node.style.gridColumn=''; node.style.gridRow=''; node.style.alignSelf=''; }
  }

  #arrangeStudioRegions(shell) {
    if(!shell?.ownerDocument) return;
    const d=shell.ownerDocument;
    const roots=[...shell.querySelectorAll?.('[data-wire-definition]')??[]].filter((node)=>node!==shell);
    const byRegion=new Map();
    for(const node of roots) {
      const region=String(node.dataset?.wireRegion??'').trim();
      if(!region || node.classList?.contains?.('wui-composition-inactive')) continue;
      if(!byRegion.has(region)) byRegion.set(region,[]);
      byRegion.get(region).push(node);
    }

    // Region wrappers are presentation-only. Never delete a wrapper that still
    // owns live Wire UI definition roots: inactive roots must survive a Studio
    // state change so the renderer can reactivate the exact same instances.
    // Also avoid re-appending a node to its current wrapper; doing so creates a
    // MutationObserver feedback loop in real browsers even though the DOM looks
    // superficially unchanged.
    const existing=new Map([...(shell.querySelectorAll?.(':scope > .wui-builder-studio-region')??[])].map((node)=>[node.dataset.wireStudioRegion,node]));
    for(const [region,nodes] of byRegion) {
      let stack=existing.get(region);
      if(!stack){
        stack=d.createElement('section');
        stack.className='wui-builder-studio-region';
        stack.dataset.wireStudioRegion=region;
        shell.append(stack);
      }
      let span=1,order=Number.POSITIVE_INFINITY;
      for(const node of nodes) {
        span=Math.max(span,Math.max(1,Math.min(12,Number(node.dataset?.wireSpan??12)||12)));
        order=Math.min(order,Number(node.dataset?.wireOrder??0)||0);
        if(node.parentElement!==stack) stack.append(node);
      }
      const gridColumn=studioRegionGridColumn(region,span);
      const gridRow=studioRegionGridRow(region,this.stateId);
      const gridArea=studioRegionGridArea(region,this.stateId);
      stack.style.gridColumn=gridColumn;
      stack.style.gridRow=gridRow;
      stack.style.gridArea=gridArea;
      stack.style.order=String(Number.isFinite(order)?order:0);
      stack.dataset.wireStudioGridColumn=gridColumn;
      stack.dataset.wireStudioGridRow=gridRow;
      if(gridArea) stack.dataset.wireStudioGridArea=gridArea; else delete stack.dataset.wireStudioGridArea;
      stack.dataset.wireStudioSpan=String(span);
      stack.hidden=false;
      existing.delete(region);
    }

    for(const stack of existing.values()) {
      const definitions=[...(stack.querySelectorAll?.('[data-wire-definition]')??[])];
      // Empty wrappers can be discarded. Wrappers containing inactive live
      // definitions are parked, hidden, rather than destroying those roots.
      if(!definitions.length) { stack.remove?.(); continue; }
      stack.hidden=true;
    }
  }

  #enhanceCanvas() {
    const canvas=this.mount.querySelector?.('[data-wire-definition^="WUIB_COMPOSITION_CANVAS@"]'); if(!canvas) return;
    const instanceId=this.#instanceIdForRoot(canvas);
    const items=[...(canvas.querySelectorAll?.('.wui-collection-item')??[])];
    const parsed=items.map((item)=>parseCollectionItemText(item.textContent??''));
    const observed=parsed.map((v)=>v.region).filter(Boolean);
    const regions=semanticRegionList(observed);
    const collection=items[0]?.parentElement??canvas;
    collection?.classList?.add?.('wui-builder-canvas-grid');
    this.#ensureCanvasGuides(canvas,collection,regions,instanceId);
    if(parsed[0]?.stateId) this.targetStateId=parsed[0].stateId;
    let selectedStillPresent=false;
    for(let index=0; index<items.length; index+=1) {
      const item=items[index]; const info=parsed[index]; const itemId=item.__wireActionDetail?.id??null;
      if(itemId && itemId===this.selectedPlacementId){this.selectedPlacementInfo=info;selectedStillPresent=true;}
      if(item.dataset?.wireCompositionSelect!=='1') {
        if(item.dataset) item.dataset.wireCompositionSelect='1';
        item.draggable=false;
        item.addEventListener?.('click',(event)=>{
          if(event?.defaultPrevented) return;
          safeStop(event);
          this.selectedPlacementId=itemId; this.selectedPlacementInfo=info;
          if(info?.stateId) this.targetStateId=info.stateId;
          this.#syncSelection(items); this.#syncRelatedLibrary(); this.#syncFlowSelection(); this.#enhanceInspector();
          if(itemId&&instanceId) void this.runtime?.sendSemanticAction?.('COMPOSITION.SELECT',{instanceId,detail:{id:itemId}});
        });
        item.addEventListener?.('dragover',(event)=>{if(this.dragSourceId)event.preventDefault?.();});
        item.addEventListener?.('drop',(event)=>{
          event.preventDefault?.(); const sourceId=this.dragSourceId; const targetId=item.__wireActionDetail?.id??null;
          this.#clearDragTargets();
          if(!sourceId||!targetId||sourceId===targetId||!instanceId) return;
          void this.runtime?.sendSemanticAction?.('DESIGN.COMPOSITION.MOVE',{instanceId,detail:{sourceId,targetId}});
        });
      }
      this.#decoratePlacement(item,info,instanceId,regions,collection);
    }
    if(this.selectedPlacementId && !selectedStillPresent){this.selectedPlacementId=null;this.selectedPlacementInfo=null;}
    this.#syncSelection(items);
  }

  #syncSelection(items=null) {
    const canvasItems=items??[...(this.mount.querySelector?.('[data-wire-definition^="WUIB_COMPOSITION_CANVAS@"]')?.querySelectorAll?.('.wui-collection-item')??[])];
    for(const item of canvasItems) {
      const selected=Boolean(this.selectedPlacementId && item.__wireActionDetail?.id===this.selectedPlacementId);
      item.classList?.toggle?.('wui-builder-placement-selected',selected);
      if(!item.classList?.toggle){if(selected)item.classList?.add?.('wui-builder-placement-selected');else item.classList?.remove?.('wui-builder-placement-selected');}
      item.setAttribute?.('aria-selected',selected?'true':'false');
    }
  }

  #decoratePlacement(item,info,instanceId,regions,collection) {
    if(!item?.ownerDocument || item.dataset?.wirePlacementDecorated==='1') return;
    item.dataset.wirePlacementDecorated='1'; item.classList?.add?.('wui-builder-placement-card');
    const d=item.ownerDocument;
    const span=Math.max(1,Math.min(12,Number(info.span??12)||12));
    item.dataset.wirePlacementRegion=info.region??'main'; item.dataset.wirePlacementSpan=String(span); item.dataset.wirePlacementAlign=String(info.align??'STRETCH').toUpperCase();
    item.style.gridColumn=`span ${span}`;
    const main=d.createElement('span'); main.className='wui-builder-placement-main';
    const eyebrow=d.createElement('span'); eyebrow.className='wui-builder-placement-type'; eyebrow.textContent=info.semanticType||'SEMANTIC ELEMENT';
    const title=d.createElement('strong'); title.className='wui-builder-placement-title'; title.textContent=info.elementId??'Placement';
    const meta=d.createElement('span'); meta.className='wui-builder-placement-meta';
    const conditions=String(info.whenConditionIds??'').trim(); const suppressions=String(info.suppressConditionIds??'').trim();
    const conditionText=conditions?` · when ${String(info.whenMode??'ALL').toUpperCase()}(${conditions})`:'';
    const suppressionText=suppressions?` · suppress ${suppressions}`:'';
    meta.textContent=`${info.region??'main'} · ${span}/12 · ${String(info.align??'STRETCH').toUpperCase()} · ${info.stateId??''}${conditionText}${suppressionText}`;
    if(conditions||suppressions){item.classList?.add?.('wui-builder-placement-conditional'); item.dataset.wirePresentationClass=String(info.presentationClass??'STANDARD').toUpperCase();}
    main.append(eyebrow,title,meta);
    const tools=d.createElement('span'); tools.className='wui-builder-placement-tools';
    const action=(label,titleText,fn)=>{const el=d.createElement('span');el.className='wui-builder-placement-handle';el.textContent=label;el.title=titleText;el.setAttribute('role','button');el.setAttribute('tabindex','0');el.addEventListener('click',(event)=>{safeStop(event);fn();});el.addEventListener('keydown',(event)=>{if(event.key==='Enter'||event.key===' '){safeStop(event);fn();}});return el;};
    const id=item.__wireActionDetail?.id;
    const align=action('↔','Cycle placement alignment',()=>{if(id&&instanceId)void this.runtime?.sendSemanticAction?.('DESIGN.COMPOSITION.ALIGN',{instanceId,detail:{id,align:nextAlignment(info.align)}});});
    const grip=d.createElement('span'); grip.className='wui-builder-drag-grip'; grip.textContent='⋮⋮'; grip.title='Drag to reorder'; grip.setAttribute('role','button'); grip.setAttribute('tabindex','0'); grip.draggable=true;
    grip.addEventListener('click',(event)=>safeStop(event));
    grip.addEventListener('dragstart',(event)=>{this.dragSourceId=id;this.dragSourceInfo=info;item.classList?.add?.('wui-builder-drag-source');if(event?.dataTransfer){event.dataTransfer.effectAllowed='move';try{event.dataTransfer.setData('text/plain',String(id??''));}catch{}}});
    grip.addEventListener('dragend',()=>{this.#clearDragTargets();});
    const resize=d.createElement('span'); resize.className='wui-builder-resize-handle'; resize.title='Drag to resize by semantic columns'; resize.setAttribute('role','separator'); resize.setAttribute('aria-orientation','vertical'); resize.setAttribute('tabindex','0');
    resize.addEventListener('click',(event)=>safeStop(event));
    resize.addEventListener('pointerdown',(event)=>{safeStop(event);this.#beginResize({event,item,info,id,instanceId,collection,meta});});
    resize.addEventListener('keydown',(event)=>{
      if(!id||!instanceId) return;
      const key=event?.key; if(key!=='ArrowLeft'&&key!=='ArrowRight') return; safeStop(event);
      const next=Math.max(1,Math.min(12,span+(key==='ArrowRight'?1:-1)));
      if(next!==span) void this.runtime?.sendSemanticAction?.('DESIGN.COMPOSITION.RESIZE',{instanceId,detail:{id,span:next}});
    });
    tools.append(align,grip);
    item.replaceChildren(main,tools,resize);
  }

  #beginResize({event,item,info,id,instanceId,collection,meta}) {
    if(!id||!instanceId||!this.window?.addEventListener) return;
    this.#endResize(null,false);
    const rect=collection?.getBoundingClientRect?.();
    const totalWidth=Number(rect?.width)||Number(collection?.clientWidth)||Number(item?.parentElement?.clientWidth)||0;
    const startX=Number(event?.clientX)||0; const startSpan=Math.max(1,Math.min(12,Number(info?.span)||12));
    this.resizeSession={item,id,instanceId,startX,startSpan,totalWidth,currentSpan:startSpan,meta,info};
    item.classList?.add?.('wui-builder-resizing');
    const move=(e)=>this.#moveResize(e); const up=(e)=>this.#endResize(e,true);
    this.resizeSession.move=move; this.resizeSession.up=up;
    this.window.addEventListener('pointermove',move); this.window.addEventListener('pointerup',up);
  }

  #moveResize(event) {
    const s=this.resizeSession; if(!s) return;
    const next=resizedSpan(s.startSpan,(Number(event?.clientX)||0)-s.startX,s.totalWidth);
    if(next===s.currentSpan) return; s.currentSpan=next;
    s.item.style.gridColumn=`span ${next}`; if(s.item.dataset)s.item.dataset.wirePlacementPreviewSpan=String(next);
    if(s.meta) s.meta.textContent=`${s.info.region??'main'} · ${next}/12 · ${String(s.info.align??'STRETCH').toUpperCase()} · ${s.info.stateId??''}`;
  }

  #endResize(event,commit) {
    const s=this.resizeSession; if(!s) return;
    this.resizeSession=null;
    this.window?.removeEventListener?.('pointermove',s.move); this.window?.removeEventListener?.('pointerup',s.up);
    s.item.classList?.remove?.('wui-builder-resizing'); if(s.item.dataset)delete s.item.dataset.wirePlacementPreviewSpan;
    if(commit&&s.currentSpan!==s.startSpan) void this.runtime?.sendSemanticAction?.('DESIGN.COMPOSITION.RESIZE',{instanceId:s.instanceId,detail:{id:s.id,span:s.currentSpan}});
    else if(!commit) s.item.style.gridColumn=`span ${s.startSpan}`;
    event?.preventDefault?.();
  }

  #ensureCanvasGuides(canvas,collection,regions,instanceId) {
    if(!canvas?.ownerDocument || !collection || collection.querySelector?.('.wui-builder-region-guides')) return;
    const d=canvas.ownerDocument; const guides=d.createElement('div'); guides.className='wui-builder-region-guides';
    const ruler=d.createElement('span'); ruler.className='wui-builder-grid-ruler';
    for(let i=1;i<=12;i+=1){const cell=d.createElement('i');cell.textContent=String(i);ruler.append(cell);}
    const regionRow=d.createElement('span'); regionRow.className='wui-builder-region-row';
    for(const region of regions){
      const chip=d.createElement('b');chip.textContent=region;chip.dataset.region=region;chip.setAttribute('role','button');chip.setAttribute('tabindex','0');chip.title=`Drop a placement into ${region}`;
      chip.addEventListener('dragenter',(event)=>{if(this.dragSourceId){event.preventDefault?.();chip.classList?.add?.('wui-builder-region-drop-active');}});
      chip.addEventListener('dragover',(event)=>{if(this.dragSourceId){event.preventDefault?.();if(event?.dataTransfer)event.dataTransfer.dropEffect='move';}});
      chip.addEventListener('dragleave',()=>chip.classList?.remove?.('wui-builder-region-drop-active'));
      chip.addEventListener('drop',(event)=>{
        event.preventDefault?.(); const id=this.dragSourceId; this.#clearDragTargets();
        if(!id||!instanceId) return;
        void this.runtime?.sendSemanticAction?.('DESIGN.COMPOSITION.RELOCATE',{instanceId,detail:{id,region}});
      });
      regionRow.append(chip);
    }
    guides.append(ruler,regionRow); collection.prepend?.(guides);
  }

  #clearDragTargets() {
    this.dragSourceId=null; this.dragSourceInfo=null;
    for(const node of [...(this.mount?.querySelectorAll?.('.wui-builder-region-drop-active,.wui-builder-drag-source')??[])]){
      node.classList?.remove?.('wui-builder-region-drop-active'); node.classList?.remove?.('wui-builder-drag-source');
    }
  }

  #enhanceInspector() {
    const root=this.mount.querySelector?.('[data-wire-definition^="WUIB_SELECTION_INSPECTOR@"]');
    if(root) {
      root.classList?.add?.('wui-builder-inspector');
      for(const row of [...(root.querySelectorAll?.('.wui-record-field')??[])]) {
        const label=String(row.querySelector?.('.wui-record-label')?.textContent??'').trim().toLowerCase().replaceAll(' ','-');
        if(label) row.dataset.wireInspectorField=label;
      }
    }
    this.#enhanceContextEditor();
  }

  #enhanceContextEditor() {
    const root=this.mount.querySelector?.('[data-wire-definition^="WUIB_COMPOSITION_EDITOR@"]'); if(!root?.ownerDocument) return;
    const d=root.ownerDocument;
    let card=root.querySelector?.('.wui-builder-context-card');
    if(!card) {
      card=d.createElement('section'); card.className='wui-builder-context-card'; root.prepend?.(card);
      const details=d.createElement('details'); details.className='wui-builder-context-advanced';
      const summary=d.createElement('summary'); summary.textContent='Advanced semantic fields'; details.append(summary);
      const fields=[...(root.querySelectorAll?.('.wui-field')??[])].filter((node)=>node.parentElement===root);
      const submit=[...(root.querySelectorAll?.('.wui-primary-action')??[])].find((node)=>node.parentElement===root);
      for(const field of fields) details.append(field); if(submit) details.append(submit); root.append(details);
    }
    const info=this.selectedPlacementInfo;
    root.classList?.toggle?.('wui-builder-context-empty',!info);
    if(!root.classList?.toggle){if(info)root.classList?.remove?.('wui-builder-context-empty');else root.classList?.add?.('wui-builder-context-empty');}
    const signature=info ? [this.selectedPlacementId,info.elementId,info.semanticType,info.stateId,info.region,info.span,info.align,info.viewportClass].join('|') : 'EMPTY';
    if(card.dataset?.wireContextSignature===signature) return; if(card.dataset)card.dataset.wireContextSignature=signature;
    card.replaceChildren();
    if(!info) {
      const empty=d.createElement('div'); empty.className='wui-builder-context-placeholder';
      const strong=d.createElement('strong'); strong.textContent='Select a placement'; const text=d.createElement('span'); text.textContent='Click a canvas card to edit its semantic layout properties.'; empty.append(strong,text); card.append(empty); return;
    }
    const hero=d.createElement('div');hero.className='wui-builder-context-hero';
    const eyebrow=d.createElement('span');eyebrow.textContent=info.semanticType||'SEMANTIC ELEMENT';
    const title=d.createElement('strong');title.textContent=info.elementId||'Placement';
    const meta=d.createElement('small');meta.textContent=`${info.stateId||'STATE'} · ${info.viewportClass||'DEFAULT'} · ${info.artifactId||''}`; hero.append(eyebrow,title,meta); card.append(hero);
    const canvas=this.mount.querySelector?.('[data-wire-definition^="WUIB_COMPOSITION_CANVAS@"]'); const instanceId=this.#instanceIdForRoot(canvas); const id=this.selectedPlacementId;
    const group=(label)=>{const g=d.createElement('div');g.className='wui-builder-property-group';const l=d.createElement('span');l.className='wui-builder-property-label';l.textContent=label;const values=d.createElement('span');values.className='wui-builder-property-values';g.append(l,values);card.append(g);return values;};
    const button=(label,active,fn)=>{const b=d.createElement('button');b.type='button';b.className='wui-builder-property-chip';b.textContent=label;b.setAttribute('aria-pressed',active?'true':'false');if(active)b.classList?.add?.('is-active');b.addEventListener('click',(event)=>{safeStop(event);fn();});return b;};
    const regions=group('Region');
    for(const region of semanticRegionList([info.region])) regions.append(button(region,region===info.region,()=>{if(id&&instanceId&&region!==info.region)void this.runtime?.sendSemanticAction?.('DESIGN.COMPOSITION.RELOCATE',{instanceId,detail:{id,region}});}));
    const spanGroup=group('Span'); const range=d.createElement('input');range.type='range';range.min='1';range.max='12';range.step='1';range.value=String(Math.max(1,Math.min(12,Number(info.span)||12)));range.className='wui-builder-span-range';range.setAttribute('aria-label','Placement span in semantic columns');
    const value=d.createElement('output');value.className='wui-builder-span-value';value.textContent=`${range.value}/12`;range.addEventListener('input',()=>{value.textContent=`${range.value}/12`;});range.addEventListener('change',(event)=>{safeStop(event);if(id&&instanceId)void this.runtime?.sendSemanticAction?.('DESIGN.COMPOSITION.RESIZE',{instanceId,detail:{id,span:Number(range.value)}});});spanGroup.append(range,value);
    const aligns=group('Align'); for(const align of ['START','CENTER','END','STRETCH']) aligns.append(button(align,align===String(info.align??'STRETCH').toUpperCase(),()=>{if(id&&instanceId&&align!==String(info.align??'STRETCH').toUpperCase())void this.runtime?.sendSemanticAction?.('DESIGN.COMPOSITION.ALIGN',{instanceId,detail:{id,align}});}));
  }

  #enhanceArtifactLibrary() {
    const root=this.mount.querySelector?.('[data-wire-definition^="WUIB_ARTIFACT_LIBRARY@"]'); if(!root) return;
    const instanceId=this.#instanceIdForRoot(root); const items=[...(root.querySelectorAll?.('.wui-collection-item')??[])];
    for(const item of items) {
      if(!item?.ownerDocument) continue;
      const rawText=item.dataset?.wireLibraryRaw??String(item.textContent??''); if(item.dataset)item.dataset.wireLibraryRaw=rawText;
      const info=parseCollectionItemText(rawText); const id=item.__wireActionDetail?.id??null;
      if(item.dataset?.wireLibraryDecorated!=='1') {
        item.dataset.wireLibraryDecorated='1'; item.classList?.add?.('wui-builder-library-item'); const d=item.ownerDocument;
        const kind=d.createElement('span');kind.className='wui-builder-library-kind';kind.textContent=info.kind??'ARTIFACT';
        const name=d.createElement('strong');name.textContent=info.artifactId??info.id??'Untitled';
        const rev=d.createElement('span');rev.className='wui-builder-library-rev';rev.textContent=`r${info.draftRevision??'?'} · v${info.publishVersion??'?'}`;
        item.replaceChildren(kind,name,rev);
        item.addEventListener?.('click',(event)=>{safeStop(event);this.selectedLibraryId=id;this.selectedPlacementId=null;this.selectedPlacementInfo=null;this.#syncLibrarySelection(items);this.#syncSelection();this.#enhanceInspector();if(id&&instanceId)void this.runtime?.sendSemanticAction?.('ARTIFACT.SELECT',{instanceId,detail:{id}});});
      }
    }
    this.#syncLibrarySelection(items);
  }

  #syncLibrarySelection(items=null) {
    const root=this.mount.querySelector?.('[data-wire-definition^="WUIB_ARTIFACT_LIBRARY@"]'); const rows=items??[...(root?.querySelectorAll?.('.wui-collection-item')??[])];
    for(const item of rows) {
      const raw=item.dataset?.wireLibraryRaw??''; const info=parseCollectionItemText(raw); const selected=Boolean(this.selectedLibraryId&&item.__wireActionDetail?.id===this.selectedLibraryId);
      const related=Boolean(this.selectedPlacementInfo?.elementId && info.kind==='ELEMENT' && info.artifactId===this.selectedPlacementInfo.elementId);
      item.classList?.toggle?.('wui-builder-library-selected',selected); item.classList?.toggle?.('wui-builder-library-related',related);
      if(!item.classList?.toggle){if(selected)item.classList?.add?.('wui-builder-library-selected');else item.classList?.remove?.('wui-builder-library-selected');if(related)item.classList?.add?.('wui-builder-library-related');else item.classList?.remove?.('wui-builder-library-related');}
    }
  }
  #syncRelatedLibrary(){this.#syncLibrarySelection();}

  #enhanceFlowMap() {
    const root=this.mount.querySelector?.('[data-wire-definition^="WUIB_FLOW_MAP@"]'); if(!root) return;
    const instanceId=this.#instanceIdForRoot(root); const items=[...(root.querySelectorAll?.('.wui-collection-item')??[])];
    for(const item of items) {
      if(!item?.ownerDocument) continue;
      const rawText=item.dataset?.wireFlowRaw??String(item.textContent??''); if(item.dataset)item.dataset.wireFlowRaw=rawText;
      const info=parseCollectionItemText(rawText); const id=item.__wireActionDetail?.id??null;
      if(item.dataset?.wireFlowDecorated!=='1') {
        item.dataset.wireFlowDecorated='1'; item.classList?.add?.('wui-builder-flow-card'); const d=item.ownerDocument;
        const state=d.createElement('strong');state.className='wui-builder-flow-state';state.textContent=info.stateId??'STATE';
        const flow=info.flowId?d.createElement('span'):null; if(flow){flow.className='wui-builder-flow-id';flow.textContent=String(info.flowId);}
        const counts=d.createElement('span');counts.className='wui-builder-flow-counts';counts.textContent=`${info.activeCount??0} active · ${info.prefetchCount??0} prefetched`;
        const signals=d.createElement('span');signals.className='wui-builder-flow-signals';
        const cb=Number(info.conditionalBranchCount??0)||0, cp=Number(info.conditionalPlacementCount??0)||0;
        if(cb){const chip=d.createElement('b');chip.className='wui-builder-flow-signal';chip.textContent=`${cb} conditional ${cb===1?'branch':'branches'}`;signals.append(chip);}
        if(cp){const chip=d.createElement('b');chip.className='wui-builder-flow-signal';chip.textContent=`${cp} conditional ${cp===1?'placement':'placements'}`;signals.append(chip);}
        const thumb=d.createElement('span'); thumb.className='wui-builder-flow-thumb'; thumb.setAttribute('aria-hidden','true');
        const placements=parseFlowLayoutSignature(info.layoutSignature??'');
        if(!placements.length){const empty=d.createElement('i'); empty.className='wui-builder-flow-thumb-empty'; thumb.append(empty);}
        for(const placement of placements.slice(0,12)){const tile=d.createElement('i'); tile.className='wui-builder-flow-thumb-tile'; tile.style.gridColumn=`span ${placement.span}`; tile.dataset.region=placement.region; tile.title=placement.elementId; thumb.append(tile);}
        const branches=d.createElement('span');branches.className='wui-builder-flow-branches';
        const branchText=String(info.branches??'').trim();
        if(branchText){for(const text of branchText.split(' | ').filter(Boolean)){const branch=d.createElement('span');branch.className='wui-builder-flow-branch';if(text.includes(' ? '))branch.classList.add('is-conditional');branch.textContent=text;branches.append(branch);}}
        else {const next=d.createElement('span');next.className='wui-builder-flow-next';next.textContent=`→ ${info.nextStates??'END'}`;branches.append(next);}
        const children=flow?[flow,state,counts]:[state,counts]; if(signals.childNodes?.length)children.push(signals); children.push(thumb,branches); item.replaceChildren(...children);
        item.addEventListener?.('click',(event)=>{safeStop(event);this.selectedFlowId=id;this.targetStateId=info.stateId??this.targetStateId;this.selectedPlacementId=null;this.selectedPlacementInfo=null;this.#syncFlowSelection(items);this.#syncSelection();this.#syncRelatedLibrary();this.#enhanceInspector();if(id&&instanceId)void this.runtime?.sendSemanticAction?.('FLOW.SELECT',{instanceId,detail:{id}});});
      }
    }
    this.#syncFlowSelection(items);
  }

  #syncFlowSelection(items=null) {
    const root=this.mount.querySelector?.('[data-wire-definition^="WUIB_FLOW_MAP@"]'); const rows=items??[...(root?.querySelectorAll?.('.wui-collection-item')??[])];
    for(const item of rows) {
      const info=parseCollectionItemText(item.dataset?.wireFlowRaw??'');
      const active=Boolean((this.selectedFlowId&&item.__wireActionDetail?.id===this.selectedFlowId)||(!this.selectedFlowId&&this.targetStateId&&info.stateId===this.targetStateId));
      item.classList?.toggle?.('wui-builder-flow-active',active); if(!item.classList?.toggle){if(active)item.classList?.add?.('wui-builder-flow-active');else item.classList?.remove?.('wui-builder-flow-active');}
      item.setAttribute?.('aria-current',active?'step':'false');
    }
  }

  #enhanceToolNav() {
    const root=this.mount.querySelector?.('[data-wire-definition^="WUIB_TOOL_NAV@"]'); if(!root) return;
    for(const item of [...(root.querySelectorAll?.('.wui-collection-item')??[])]) {
      const label=String(item.textContent??'').trim().toUpperCase();
      if(this.stateId && label===String(this.stateId).toUpperCase()) item.classList?.add?.('wui-builder-tool-active'); else item.classList?.remove?.('wui-builder-tool-active');
    }
  }

  #instanceIdForRoot(root) {
    for(const [instanceId,live] of this.renderer?.instances??[]) if(live?.root===root) return instanceId;
    return null;
  }
}
