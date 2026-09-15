import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const {BuilderCompositionController,viewportClassForWidth,stateFromJourneyPlan,selectCompositionHint,placementPresentation,parseCollectionItemText,nextRegion,nextAlignment,parseFlowLayoutSignature,semanticRegionList,resizedSpan,studioRegionGridColumn,studioRegionGridRow,studioRegionGridArea}=await import(pathToFileURL(path.join(root,'web/composition-controller.js')).href);

function assert(ok,msg){if(!ok)throw new Error(msg);}
assert(viewportClassForWidth(390)==='SMALL','small viewport');
assert(viewportClassForWidth(800)==='MEDIUM','medium viewport');
assert(viewportClassForWidth(1440)==='LARGE','large viewport');
const parsedText=parseCollectionItemText('elementId: A · region: main · span: 6'); assert(parsedText.elementId==='A'&&parsedText.region==='main'&&parsedText.span==='6','collection presentation parser');
assert(nextRegion('main',['main','sidebar'])==='sidebar','region cycling follows observed semantic regions');
assert(nextAlignment('STRETCH')==='START'&&nextAlignment('END')==='STRETCH','alignment cycling is deterministic');
const regions=semanticRegionList(['custom','main']); assert(regions[0]==='custom'&&regions.includes('header')&&regions.includes('footer'),'semantic region drop targets include observed and generic regions');
assert(resizedSpan(6,100,1200)===7&&resizedSpan(6,-700,1200)===1&&resizedSpan(10,900,1200)===12,'pointer resize resolves to bounded semantic columns');
assert(studioRegionGridColumn('library',3)==='1 / 4'&&studioRegionGridColumn('canvas',6)==='4 / 10'&&studioRegionGridColumn('inspector',3)==='10 / 13'&&studioRegionGridColumn('flow',12)==='1 / 13','structural Studio regions use deterministic GRID12 lines');
assert(studioRegionGridColumn('editors',6)==='auto / span 6','unrecognised semantic regions retain authored span through explicit grid-end syntax');
assert(studioRegionGridColumn('sidebar',3)==='auto / span 3'&&studioRegionGridColumn('main',5)==='auto / span 5','target authoring regions are not mistaken for Studio chrome regions');
assert(studioRegionGridRow('header','DESIGN')==='1'&&studioRegionGridRow('canvas','DESIGN')==='3'&&studioRegionGridRow('flow','DESIGN')==='4','DESIGN chrome uses explicit rows');
assert(studioRegionGridArea('library','DESIGN')==='library'&&studioRegionGridArea('flow','DESIGN')==='flow'&&studioRegionGridArea('sidebar','DESIGN')==='','DESIGN named areas are Studio chrome only');
assert(studioRegionGridArea('source-list','SOURCE')==='source-list'&&studioRegionGridArea('source-detail','SOURCE')==='source-detail','SOURCE has distinct catalogue/detail areas');
assert(studioRegionGridRow('source-list','SOURCE')==='3'&&studioRegionGridRow('source-detail','SOURCE')==='3','SOURCE catalogue and detail share the workbench row');
assert(studioRegionGridArea('component-editor','COMPONENTS')==='component-editor'&&studioRegionGridArea('projection-editor','COMPONENTS')==='projection-editor','COMPONENTS editor roots remain distinct');
assert(studioRegionGridArea('material-editor','MATERIALS')==='material-editor'&&studioRegionGridArea('preview','MATERIALS')==='preview','MATERIALS editor and preview remain distinct');
assert(studioRegionGridArea('journey-editor','FLOW')==='journey-editor'&&studioRegionGridArea('policy-editor','FLOW')==='policy-editor','FLOW authoring perspectives remain distinct');
assert(studioRegionGridArea('publish','PUBLISH')==='publish','PUBLISH has an explicit action area');
const mini=parseFlowLayoutSignature('main~6~A~STRETCH|sidebar~6~B~CENTER'); assert(mini.length===2&&mini[0].span===6&&mini[1].region==='sidebar','flow thumbnail signature parsed');
assert(stateFromJourneyPlan({planId:'BUILDER-APP:DESIGN:7'},'BUILDER-APP')==='DESIGN','state decoded from server plan');
const hintDefault={stateId:'DESIGN',layoutModel:'GRID12',placement:{viewportClass:'DEFAULT',region:'canvas',order:20,span:6,rowSpan:1,align:'STRETCH'}};
const hintSmall={stateId:'DESIGN',layoutModel:'GRID12',placement:{viewportClass:'SMALL',region:'canvas',order:5,span:12,rowSpan:1,align:'START'}};
const definition={semantic:{metadata:{compositionHints:[hintDefault,hintSmall]}}};
assert(selectCompositionHint(definition,{stateId:'DESIGN',viewportClass:'SMALL'})===hintSmall,'exact viewport wins');
assert(selectCompositionHint(definition,{stateId:'DESIGN',viewportClass:'LARGE'})===hintDefault,'default viewport fallback');
const presented=placementPresentation(hintDefault); assert(presented.span===6&&presented.region==='canvas'&&presented.alignSelf==='stretch','typed placement interpreted');

class ClassListFake{
  constructor(){this.values=new Set();}
  add(...xs){for(const x of xs)this.values.add(x);} remove(...xs){for(const x of xs)this.values.delete(x);} contains(x){return this.values.has(x);} toggle(x,on){if(on===undefined)on=!this.values.has(x);if(on)this.values.add(x);else this.values.delete(x);return on;}
}
class ElementFake{
  constructor(tag='div',doc=null){this.tagName=tag.toUpperCase();this.ownerDocument=doc;this.attrs={};this.dataset={};this.style={};this.listeners={};this.children=[];this.classList=new ClassListFake();this.parentElement=null;this.textContent='';this.draggable=false;this.clientWidth=1200;this.appendOps=0;}
  set className(v){this._className=v;this.classList=new ClassListFake();for(const x of String(v).split(/\s+/).filter(Boolean))this.classList.add(x);} get className(){return this._className??[...this.classList.values].join(' ');}
  setAttribute(k,v){this.attrs[k]=String(v);} getAttribute(k){return this.attrs[k]??null;}
  addEventListener(k,fn){(this.listeners[k]??=[]).push(fn);} removeEventListener(){}
  emit(k,event={}){for(const fn of this.listeners[k]??[])fn(event);}
  append(...nodes){for(const n of nodes){if(n==null)continue;this.appendOps+=1;if(n.parentElement){const i=n.parentElement.children.indexOf(n);if(i>=0)n.parentElement.children.splice(i,1);}n.parentElement=this;this.children.push(n);}}
  prepend(...nodes){for(const n of nodes.reverse()){if(n==null)continue;if(n.parentElement){const i=n.parentElement.children.indexOf(n);if(i>=0)n.parentElement.children.splice(i,1);}n.parentElement=this;this.children.unshift(n);}}
  replaceChildren(...nodes){for(const n of this.children)n.parentElement=null;this.children=[];this.append(...nodes);}
  remove(){if(this.parentElement){const i=this.parentElement.children.indexOf(this);if(i>=0)this.parentElement.children.splice(i,1);this.parentElement=null;}}
  getBoundingClientRect(){return {width:this.clientWidth};}
  #descendants(){const out=[];const walk=(n)=>{for(const c of n.children){out.push(c);walk(c);}};walk(this);return out;}
  querySelectorAll(sel){
    if(sel==='[data-wire-definition]') return this.#descendants().filter((n)=>n.attrs['data-wire-definition']);
    if(sel===':scope > .wui-builder-studio-region') return this.children.filter((n)=>n.classList.contains('wui-builder-studio-region'));
    if(sel.startsWith('.')){const names=sel.split(',').map((s)=>s.trim().slice(1));return this.#descendants().filter((n)=>names.some((x)=>n.classList.contains(x)));}
    return [];
  }
  querySelector(sel){return this.querySelectorAll(sel)[0]??null;}
}
class DocumentFake{createElement(tag){return new ElementFake(tag,this);}}
const doc=new DocumentFake();
const shell=new ElementFake('div',doc);shell.attrs['data-wire-definition']='WUIB_SHELL@1';
const canvas=new ElementFake('div',doc);canvas.attrs['data-wire-definition']='WUIB_COMPOSITION_CANVAS@1';
const library=new ElementFake('div',doc);library.attrs['data-wire-definition']='WUIB_ARTIFACT_LIBRARY@1';
const inspector=new ElementFake('div',doc);inspector.attrs['data-wire-definition']='WUIB_SELECTION_INSPECTOR@1';
const flow=new ElementFake('div',doc);flow.attrs['data-wire-definition']='WUIB_FLOW_MAP@1';
const inactive=new ElementFake('div',doc);inactive.attrs['data-wire-definition']='WUIB_COMPONENT_EDITOR@1';
const material=new ElementFake('div',doc);material.attrs['data-wire-definition']='WUIB_MATERIAL_EDITOR@1';
const first=new ElementFake('button',doc); first.className='wui-collection-item'; first.textContent='id: HOME_LAYOUT|HOME|DEFAULT|A| · artifactId: HOME_LAYOUT · stateId: HOME · elementId: A · semanticType: SEARCH · region: main · span: 6 · align: STRETCH'; first.__wireActionDetail={id:'HOME_LAYOUT|HOME|DEFAULT|A|'};
const second=new ElementFake('button',doc); second.className='wui-collection-item'; second.textContent='id: HOME_LAYOUT|HOME|DEFAULT|B| · artifactId: HOME_LAYOUT · stateId: HOME · elementId: B · semanticType: DETAIL · region: sidebar · span: 6 · align: STRETCH'; second.__wireActionDetail={id:'HOME_LAYOUT|HOME|DEFAULT|B|'};
canvas.append(first,second);
shell.append(library,canvas,inspector,flow,inactive,material);
const libraryDefinition={semantic:{metadata:{compositionHints:[{stateId:'DESIGN',layoutModel:'GRID12',placement:{viewportClass:'DEFAULT',region:'library',order:10,span:3,rowSpan:1,align:'STRETCH'}}]}}};
const inspectorDefinition={semantic:{metadata:{compositionHints:[{stateId:'DESIGN',layoutModel:'GRID12',placement:{viewportClass:'DEFAULT',region:'inspector',order:30,span:3,rowSpan:1,align:'STRETCH'}}]}}};
const flowDefinition={semantic:{metadata:{compositionHints:[{stateId:'DESIGN',layoutModel:'GRID12',placement:{viewportClass:'DEFAULT',region:'flow',order:50,span:12,rowSpan:1,align:'STRETCH'}}]}}};
const materialDefinition={semantic:{metadata:{compositionHints:[{stateId:'MATERIALS',layoutModel:'GRID12',placement:{viewportClass:'DEFAULT',region:'editors',order:10,span:6,rowSpan:1,align:'STRETCH'}}]}}};
const definitions={get:(id)=> id==='WUIB_COMPOSITION_CANVAS'?definition:(id==='WUIB_ARTIFACT_LIBRARY'?libraryDefinition:(id==='WUIB_SELECTION_INSPECTOR'?inspectorDefinition:(id==='WUIB_FLOW_MAP'?flowDefinition:(id==='WUIB_MATERIAL_EDITOR'?materialDefinition:{semantic:{metadata:{}}}))))};
const allRoots=[shell,library,canvas,inspector,flow,inactive,material];
const mount={
  querySelectorAll:(sel)=>sel==='[data-wire-definition]'?allRoots:(sel.startsWith('.')?[...canvas.querySelectorAll(sel)]:[]),
  querySelector:(sel)=>sel.startsWith('[data-wire-definition^="WUIB_COMPOSITION_CANVAS@')?canvas:null
};
const calls=[]; const runtime={sendSemanticAction:(action,args)=>{calls.push({action,args});return Promise.resolve();}};
const renderer={instances:new Map([['composition-canvas',{root:canvas}]])};
let journeyHandler=null; const journeyController={onState:(fn)=>{journeyHandler=fn;return()=>{};}};
const winListeners=new Map(); const win={innerWidth:390,addEventListener(k,fn){winListeners.set(k,fn);},removeEventListener(k){winListeners.delete(k);}};
const controller=new BuilderCompositionController({runtime,renderer,definitions,mount,journeyController,ownership:{applicationId:'BUILDER-APP'},window:win,MutationObserverImpl:null}).start();
journeyHandler({type:'journey-plan-installed',plan:{planId:'BUILDER-APP:DESIGN:1'}});
assert(canvas.style.gridColumn==='span 12','live Studio composition applies small viewport placement');
assert(shell.classList.values.has('wui-builder-composition-grid'),'Studio shell becomes composition grid');
assert(!shell.classList.values.has('wui-composition-inactive'),'Studio shell is never hidden as an inactive placement');
assert(inactive.classList.values.has('wui-composition-inactive'),'elements outside active composition are presentation-hidden');
const libraryStack=shell.children.find((n)=>n.dataset?.wireStudioRegion==='library');
const canvasStack=shell.children.find((n)=>n.dataset?.wireStudioRegion==='canvas');
const inspectorStack=shell.children.find((n)=>n.dataset?.wireStudioRegion==='inspector');
const flowStack=shell.children.find((n)=>n.dataset?.wireStudioRegion==='flow');
assert(libraryStack?.style.gridColumn==='1 / 4','library stack is pinned to GRID12 columns 1-3');
assert(canvasStack?.style.gridColumn==='4 / 10','canvas stack is pinned to GRID12 columns 4-9');
assert(inspectorStack?.style.gridColumn==='10 / 13','inspector stack is pinned to GRID12 columns 10-12');
assert(flowStack?.style.gridColumn==='1 / 13','flow stack is pinned full-width instead of collapsing to one auto track');
assert(libraryStack?.style.gridRow==='3'&&canvasStack?.style.gridRow==='3'&&inspectorStack?.style.gridRow==='3'&&flowStack?.style.gridRow==='4','DESIGN chrome pins workbench and flow to separate rows');
assert(libraryStack?.style.gridArea==='library'&&canvasStack?.style.gridArea==='canvas'&&inspectorStack?.style.gridArea==='inspector'&&flowStack?.style.gridArea==='flow','DESIGN chrome carries named grid areas');
assert(canvasStack&&canvas.parentElement===canvasStack&&!canvasStack.hidden,'active canvas is housed in a visible semantic region stack');
const stableAppendOps=canvasStack.appendOps;
journeyHandler({type:'journey-plan-installed',plan:{planId:'BUILDER-APP:DESIGN:2'}});
assert(canvasStack.appendOps===stableAppendOps,'reapplying one Studio state does not reappend already-parented roots');
journeyHandler({type:'journey-plan-installed',plan:{planId:'BUILDER-APP:MATERIALS:3'}});
const editorStack=shell.children.find((n)=>n.dataset?.wireStudioRegion==='editors');
assert(canvas.parentElement===canvasStack&&shell.querySelectorAll('[data-wire-definition]').includes(canvas),'inactive state switch parks rather than deletes live definition roots');
assert(canvasStack.hidden===true&&editorStack&&editorStack.hidden===false&&material.parentElement===editorStack,'state switch hides parked DESIGN region and exposes MATERIALS region');
journeyHandler({type:'journey-plan-installed',plan:{planId:'BUILDER-APP:DESIGN:4'}});
assert(canvas.parentElement===canvasStack&&canvasStack.hidden===false,'returning to DESIGN reuses the exact live canvas root and wrapper');
assert(material.parentElement===editorStack&&editorStack.hidden===true,'inactive MATERIALS root remains parked for later reuse');
assert(first.draggable===false&&second.draggable===false,'canvas cards are not whole-card drag sources');

const event=()=>({preventDefault(){this.prevented=true;},stopPropagation(){this.stopped=true;},key:'',dataTransfer:{effectAllowed:'',dropEffect:'',setData(){}}});
first.emit('click',event()); await new Promise((r)=>setTimeout(r,0));
assert(calls.at(-1)?.action==='COMPOSITION.SELECT','canvas click emits authoritative composition selection');
assert(calls.at(-1)?.args.detail.id===first.__wireActionDetail.id,'composition selection carries opaque placement id');
assert(first.classList.contains('wui-builder-placement-selected'),'canvas selection is visibly synchronised');

const grip=first.querySelector('.wui-builder-drag-grip'); assert(grip&&grip.draggable===true,'dedicated reorder grip is draggable');
grip.emit('dragstart',event()); second.emit('drop',event()); await new Promise((r)=>setTimeout(r,0));
assert(calls.at(-1)?.action==='DESIGN.COMPOSITION.MOVE','grip drag between cards emits typed move');

const footer=[...canvas.querySelectorAll('.wui-builder-region-row')][0]?.children.find((n)=>n.dataset.region==='footer'); assert(footer,'semantic footer drop target rendered');
grip.emit('dragstart',event()); footer.emit('drop',event()); await new Promise((r)=>setTimeout(r,0));
assert(calls.at(-1)?.action==='DESIGN.COMPOSITION.RELOCATE'&&calls.at(-1)?.args.detail.region==='footer','region drop emits typed relocate');

const resize=first.querySelector('.wui-builder-resize-handle'); assert(resize,'semantic resize handle rendered');
const keyEvent=event(); keyEvent.key='ArrowRight'; resize.emit('keydown',keyEvent); await new Promise((r)=>setTimeout(r,0));
assert(calls.at(-1)?.action==='DESIGN.COMPOSITION.RESIZE'&&calls.at(-1)?.args.detail.span===7,'resize handle keyboard path emits absolute semantic span');

controller.stop();
console.log('PASS test_composition_controller v0.11 deterministic Studio areas + selection/drop/resize ergonomics');
