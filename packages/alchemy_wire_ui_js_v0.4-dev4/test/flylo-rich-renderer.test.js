import test from 'node:test';
import assert from 'node:assert/strict';
import { DefinitionRegistry, BrowserRenderer, adaptServerDefinition } from '../src/index.js';

class FakeNode {
  constructor(tag, document) { this.tagName=String(tag).toUpperCase(); this.ownerDocument=document; this.children=[]; this.attributes=new Map(); this.listeners=new Map(); this.textContent=''; this.value=''; this.hidden=false; this.disabled=false; this.className=''; this.parent=null; }
  setAttribute(n,v){this.attributes.set(n,String(v)); if(n==='value')this.value=String(v);}
  removeAttribute(n){this.attributes.delete(n);}
  addEventListener(n,h){this.listeners.set(n,h);}
  appendChild(c){c.remove(); c.parent=this; this.children.push(c);}
  insertBefore(c,b){c.remove(); c.parent=this; const i=this.children.indexOf(b); if(i<0)this.children.push(c); else this.children.splice(i,0,c);}
  replaceChildren(...cs){for(const c of this.children)c.parent=null; this.children=[]; for(const c of cs)this.appendChild(c);}
  remove(){if(!this.parent)return; this.parent.children=this.parent.children.filter(c=>c!==this); this.parent=null;}
  fire(name,event={}){this.listeners.get(name)?.({currentTarget:this,target:event.target??this,preventDefault(){},...event});}
}
class FakeDocument { createElement(tag){return new FakeNode(tag,this);} }

function install(definition){const registry=new DefinitionRegistry({profileId:definition.profileId??'*'}); registry.install(definition); return registry;}

test('FlyLo FORM metadata becomes real fields and preserves diagnostic identities',()=>{
  const adapted=adaptServerDefinition({definitionId:'FLYLO_SEARCH_FORM',definitionVersion:1,definitionKey:'FLYLO_SEARCH_FORM@1',primitive:'FORM',semanticAction:'FLIGHT.SEARCH',metadata:{profile:'HUMAN_VISUAL',styleRole:'hero-search',materialRole:'PRIMARY',semanticElementRef:{id:'FLIGHT_SEARCH',version:1,kind:'semantic'},projectionRef:{id:'FLIGHT_SEARCH.HUMAN_VISUAL',version:1,kind:'projection'},componentRef:{id:'FLYLO_SEARCH',version:1,kind:'component'},bindings:{origin:'origin',destination:'destination',date:'date',passengers:'passengers'}}});
  assert.match(adapted.nodes.find(n=>n.key==='root').className,/wui-hero-search/);
  assert.equal(adapted.nodes.find(n=>n.key==='root').attrs['data-wire-definition'],'FLYLO_SEARCH_FORM@1');
  assert.match(adapted.nodes.find(n=>n.key==='root').attrs['data-wire-semantic'],/FLIGHT_SEARCH@1/);
  const document=new FakeDocument(), mount=document.createElement('main'), actions=[];
  const renderer=new BrowserRenderer({definitions:install(adapted),mount,document}); renderer.setActionSink(a=>actions.push(a));
  renderer.createInstance({instanceId:'search',definitionId:'FLYLO_SEARCH_FORM',definitionVersion:1,slots:{origin:'PIK',destination:'EWR',date:'2026-09-01',passengers:'5'}}); renderer.setRoot('search');
  const live=renderer.instances.get('search'); const names=[...live.nodes.values()].filter(n=>n.attributes?.has('name')).map(n=>n.attributes.get('name'));
  assert.deepEqual(names,['origin','destination','date','passengers']);
  live.root.fire('submit');
  assert.deepEqual(actions[0].detail,{origin:'PIK',destination:'EWR',date:'2026-09-01',passengers:'5'});
});


test('semantic interaction profile is distinct from negotiated render profile',()=>{
  const adapted=adaptServerDefinition({definitionId:'FLYLO_SEARCH_FORM',definitionVersion:2,primitive:'FORM',profileId:'large-fine',metadata:{profile:'HUMAN_VISUAL',bindings:{origin:'origin'}}});
  assert.equal(adapted.profileId,'large-fine');
  assert.equal(adapted.semantic.interactionProfile,'HUMAN_VISUAL');
  const root=adapted.nodes.find(n=>n.key==='root');
  assert.equal(root.attrs['data-wire-profile'],'HUMAN_VISUAL');
  assert.equal(root.attrs['data-wire-render-profile'],'large-fine');
});

test('FlyLo OFFER_LIST renders actionable collection items returning only server identity and index',()=>{
  const adapted=adaptServerDefinition({definitionId:'FLYLO_OFFER_CARDS',definitionVersion:1,definitionKey:'FLYLO_OFFER_CARDS@1',primitive:'OFFER_LIST',semanticAction:'FLIGHT.SELECT',metadata:{profile:'HUMAN_VISUAL',styleRole:'utility-card'}});
  const document=new FakeDocument(), mount=document.createElement('main'), actions=[];
  const renderer=new BrowserRenderer({definitions:install(adapted),mount,document}); renderer.setActionSink(a=>actions.push(a));
  renderer.createInstance({instanceId:'offers',definitionId:'FLYLO_OFFER_CARDS',definitionVersion:1,slots:{offers:[{offerId:'OFF-7',origin:'PIK',destination:'EWR',fare:'199.00',currency:'GBP'},{offerId:'OFF-8',fare:'249.00',currency:'GBP'}]}});
  const live=renderer.instances.get('offers'); assert.equal(live.root.children.length,2); assert.equal(live.root.children[0].tagName,'BUTTON');
  live.root.fire('click',{target:live.root.children[0]});
  assert.deepEqual(actions[0].detail,{index:0,offerId:'OFF-7'});
  assert.equal('fare' in actions[0].detail,false);
});

test('rich semantic composition keeps styleRole on the composed root',()=>{
  const adapted=adaptServerDefinition({definitionId:'ASK_FLYLO',definitionVersion:2,primitive:'SEMANTIC_RECORD',semanticAction:'ASSISTANT.ASK',metadata:{profile:'HUMAN_VISUAL',styleRole:'assistant-panel',bindings:{message:'message',answer:'answer'}}});
  const root=adapted.nodes.find(n=>n.key==='root'); assert.match(root.className,/wui-assistant-panel/); assert.equal(root.attrs['data-wire-profile'],'HUMAN_VISUAL');
});


test('FlyLo CHOICE_LIST precompiles to boolean fields and semantic submit',()=>{
  const adapted=adaptServerDefinition({definitionId:'FLYLO_EXTRAS',definitionVersion:1,primitive:'CHOICE_LIST',semanticAction:'ANCILLARY.SAVE',metadata:{profile:'HUMAN_VISUAL',bindings:{saleId:'saleId',CABIN_BAG:'CABIN_BAG',CHECKED_BAG:'CHECKED_BAG'}}});
  const document=new FakeDocument(), mount=document.createElement('main'), actions=[];
  const renderer=new BrowserRenderer({definitions:install(adapted),mount,document}); renderer.setActionSink(a=>actions.push(a));
  renderer.createInstance({instanceId:'extras',definitionId:'FLYLO_EXTRAS',definitionVersion:1,slots:{saleId:'SALE-1',CABIN_BAG:true,CHECKED_BAG:false}});
  const live=renderer.instances.get('extras'); const checkbox=[...live.nodes.values()].find(n=>n.attributes?.get('name')==='CHECKED_BAG'); checkbox.checked=true;
  live.root.fire('submit');
  assert.deepEqual(actions[0].detail,{saleId:'SALE-1',CABIN_BAG:true,CHECKED_BAG:true});
});

test('FlyLo TOKEN_FORM is precompilable as a semantic form',()=>{
  const adapted=adaptServerDefinition({definitionId:'FLYLO_PAYMENT',definitionVersion:1,primitive:'TOKEN_FORM',semanticAction:'PAYMENT.AUTHORIZE',metadata:{profile:'HUMAN_VISUAL',bindings:{saleId:'saleId',paymentMethodToken:'paymentMethodToken'}}});
  const document=new FakeDocument(), mount=document.createElement('main'), actions=[];
  const renderer=new BrowserRenderer({definitions:install(adapted),mount,document}); renderer.setActionSink(a=>actions.push(a));
  renderer.createInstance({instanceId:'payment',definitionId:'FLYLO_PAYMENT',definitionVersion:1,slots:{saleId:'SALE-2',paymentMethodToken:'tok_fixture'}});
  const live=renderer.instances.get('payment');
  const saleField=[...live.nodes.values()].find(n=>n.attributes?.get('name')==='saleId');
  assert.equal(saleField.attributes.get('type'),'hidden');
  assert.equal(saleField.attributes.get('data-wire-ui-authority'),'server');
  assert.equal([...live.nodes.values()].some(n=>n.tagName==='LABEL'&&n.textContent==='Sale Id'),false);
  live.root.fire('submit');
  assert.equal(actions[0].detail.paymentMethodToken,'tok_fixture');
});
