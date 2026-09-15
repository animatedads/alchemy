const primitiveMap = Object.freeze({
  PANEL: 'container', CONTAINER: 'container', TEXT: 'text', STATUS: 'text',
  ACTION_BUTTON: 'button', BUTTON: 'button', MODE_SWITCH_OFFER: 'button', INPUT: 'input',
  FORM: 'form', TOKEN_FORM: 'form', CHOICE_LIST: 'form', LIST: 'list', OFFER_LIST: 'list', OFFER_SELECTOR: 'list', DOCUMENT: 'document',
  SEMANTIC_RECORD: 'semantic-record', SEMANTIC_COLLECTION: 'list'
});

const standardSlots = Object.freeze({
  container: [['visible','visible'],['ariaLabel','ariaLabel']],
  text: [['value','text'],['text','text'],['visible','visible'],['ariaLabel','ariaLabel']],
  button: [['text','text'],['label','text'],['enabled','enabled'],['visible','visible'],['ariaLabel','ariaLabel']],
  input: [['value','value'],['enabled','enabled'],['visible','visible'],['ariaLabel','ariaLabel']],
  form: [['visible','visible'],['ariaLabel','ariaLabel']],
  list: [['items','collection'],['offers','collection'],['visible','visible'],['ariaLabel','ariaLabel']],
  document: [['value','text'],['text','text'],['visible','visible'],['ariaLabel','ariaLabel']],
  'semantic-record': [['visible','visible'],['ariaLabel','ariaLabel']]
});

function versionNumber(value) { const n=Number(value??1); if(!Number.isSafeInteger(n)||n<1) throw new TypeError(`invalid definition version ${value}`); return n; }
function definitionVersion(value) { return versionNumber(value?.definitionVersion ?? value?.version ?? 1); }
function actionEvent(serverPrimitive) { const p=String(serverPrimitive??'').toUpperCase(); if(['FORM','TOKEN_FORM','CHOICE_LIST'].includes(p)) return {event:'submit',preventDefault:true}; if(p==='INPUT') return {event:'change',detail:'value'}; if(['LIST','OFFER_LIST','OFFER_SELECTOR','SEMANTIC_COLLECTION'].includes(p)) return {event:'click',detail:{kind:'collection-item'}}; return {event:'click'}; }
function parseDefinitionKey(key) { if(typeof key!=='string')return null; const at=key.lastIndexOf('@'); if(at<=0||at===key.length-1)return null; const version=Number(key.slice(at+1)); if(!Number.isSafeInteger(version)||version<1)return null; return {id:key.slice(0,at),version}; }
function classToken(value) { return String(value??'').trim().replace(/[^A-Za-z0-9_-]+/g,'-').replace(/^-+|-+$/g,''); }
function humanLabel(value) { return String(value).replace(/[_-]+/g,' ').replace(/([a-z])([A-Z])/g,'$1 $2').replace(/^./,c=>c.toUpperCase()); }
function inputType(name) { const n=String(name).toLowerCase(); if(n.includes('date'))return 'date'; if(n.includes('passenger')||n.includes('count')||n.includes('quantity'))return 'number'; if(n.includes('email'))return 'email'; return 'text'; }
function metadataOf(d) { return d?.metadata && typeof d.metadata==='object' ? d.metadata : {}; }
function semanticValue(d,key,fallback=null) { const m=metadataOf(d); return d?.[key] ?? m?.[key] ?? fallback; }
function bindingsOf(d) { const b=semanticValue(d,'bindings',{}); return b && typeof b==='object' ? b : {}; }
function refToken(value) { if(value==null)return null; if(typeof value==='string')return value; if(typeof value==='object'&&value.id){const kind=value.kind?`${value.kind}:`:''; const version=value.version!=null?`@${value.version}`:''; return `${kind}${value.id}${version}`;} return String(value); }

function formDefinition({ primitive, sourcePrimitive, serverDefinition, nodes, slots, actions, action }) {
  const bindings=bindingsOf(serverDefinition); const entries=Object.entries(bindings);
  if(!entries.length) return false;
  nodes.length=0; slots.length=0; actions.length=0;
  nodes.push({key:'root',primitive:'form'});
  const fields=[]; let index=0;
  for(const [projectionName, semanticNameRaw] of entries){
    const semanticName=String(semanticNameRaw ?? projectionName); const inputKey=`field-${index}`;
    const serverIdentity=String(projectionName).toLowerCase()==='saleid'||semanticName.toLowerCase()==='saleid';
    if(serverIdentity){
      nodes.push({key:inputKey,primitive:'input',parent:'root',attrs:{name:semanticName,type:'hidden','data-wire-ui-field':semanticName,'data-wire-ui-authority':'server'}});
    } else {
      const labelKey=`label-${index}`;
      nodes.push({key:labelKey,primitive:'label',parent:'root',text:humanLabel(projectionName),className:'wui-field'});
      nodes.push({key:inputKey,primitive:'input',parent:labelKey,attrs:{name:semanticName,type:inputType(projectionName),'data-wire-ui-field':semanticName}});
    }
    slots.push({index:index++,name:semanticName,target:inputKey,writer:'value'});
    if(semanticName!==projectionName) slots.push({index:index++,name:projectionName,target:inputKey,writer:'value'});
    fields.push({name:semanticName,target:inputKey});
  }
  const submitKey='submit'; nodes.push({key:submitKey,primitive:'button',parent:'root',text:'Continue',attrs:{type:'submit'},className:'wui-primary-action'});
  slots.push({index:index++,name:'visible',target:'root',writer:'visible'}); slots.push({index:index++,name:'ariaLabel',target:'root',writer:'ariaLabel'});
  if(action) actions.push({target:'root',action,event:'submit',preventDefault:true,detail:{kind:'fields',fields}});
  return true;
}

function choiceListDefinition({ serverDefinition, nodes, slots, actions, action }) {
  const bindings=bindingsOf(serverDefinition); const entries=Object.entries(bindings);
  if(!entries.length) return false;
  nodes.length=0; slots.length=0; actions.length=0; nodes.push({key:'root',primitive:'form'});
  const fields=[]; let index=0;
  for(const [projectionName, semanticNameRaw] of entries){
    const semanticName=String(semanticNameRaw??projectionName);
    if(String(projectionName).toLowerCase()==='saleid'){
      const inputKey=`field-${index}`; nodes.push({key:inputKey,primitive:'input',parent:'root',attrs:{name:semanticName,type:'hidden','data-wire-ui-field':semanticName}});
      slots.push({index:index++,name:semanticName,target:inputKey,writer:'value'}); fields.push({name:semanticName,target:inputKey,property:'value'}); continue;
    }
    const labelKey=`label-${index}`, inputKey=`field-${index}`;
    nodes.push({key:labelKey,primitive:'label',parent:'root',text:humanLabel(projectionName),className:'wui-choice'});
    nodes.push({key:inputKey,primitive:'input',parent:labelKey,attrs:{name:semanticName,type:'checkbox','data-wire-ui-field':semanticName}});
    slots.push({index:index++,name:semanticName,target:inputKey,writer:'checked'});
    fields.push({name:semanticName,target:inputKey,property:'checked'});
  }
  nodes.push({key:'submit',primitive:'button',parent:'root',text:'Continue',attrs:{type:'submit'},className:'wui-primary-action'});
  slots.push({index:index++,name:'visible',target:'root',writer:'visible'}); slots.push({index:index++,name:'ariaLabel',target:'root',writer:'ariaLabel'});
  if(action) actions.push({target:'root',action,event:'submit',preventDefault:true,detail:{kind:'fields',fields}});
  return true;
}

function semanticRecordDefinition({ serverDefinition, nodes, slots, actions, action }) {
  const bindings=bindingsOf(serverDefinition); const entries=Object.entries(bindings);
  if(!entries.length) return false;
  nodes.length=0; slots.length=0; actions.length=0; nodes.push({key:'root',primitive:'semantic-record'});
  let index=0; const fields=[];
  for(const [projectionName,semanticNameRaw] of entries){
    const semanticName=String(semanticNameRaw??projectionName); const row=`row-${index}`; const value=`value-${index}`;
    nodes.push({key:row,primitive:'container',parent:'root',className:'wui-record-field'});
    nodes.push({key:`label-${index}`,primitive:'text',parent:row,text:humanLabel(projectionName),className:'wui-record-label'});
    if(String(projectionName).toLowerCase()==='message' && action){
      nodes.push({key:value,primitive:'input',parent:row,attrs:{name:semanticName,'data-wire-ui-field':semanticName},className:'wui-record-input'});
      slots.push({index:index++,name:semanticName,target:value,writer:'value'}); fields.push({name:semanticName,target:value});
    } else {
      nodes.push({key:value,primitive:'text',parent:row,className:'wui-record-value'});
      slots.push({index:index++,name:semanticName,target:value,writer:'text'});
    }
  }
  if(action){ const button='action'; nodes.push({key:button,primitive:'button',parent:'root',text:'Send',attrs:{type:'button'},className:'wui-primary-action'}); actions.push({target:button,action,event:'click',detail:{kind:'fields',fields}}); }
  slots.push({index:index++,name:'visible',target:'root',writer:'visible'}); slots.push({index:index++,name:'ariaLabel',target:'root',writer:'ariaLabel'});
  return true;
}

/** Adapt exact ooRexx/Builder semantic definitions to browser render definitions. */
export function adaptServerDefinition(serverDefinition) {
  if(!serverDefinition?.definitionId) throw new TypeError('server definitionId is required');
  const sourcePrimitive=String(serverDefinition.primitive??'').toUpperCase(); const primitive=primitiveMap[sourcePrimitive];
  if(!primitive) throw new Error(`unsupported ooRexx primitive ${serverDefinition.primitive}`);
  const semanticProfile=semanticValue(serverDefinition,'profile','*');
  const renderProfile=serverDefinition.profileId??semanticProfile??'*';
  const styleRole=semanticValue(serverDefinition,'styleRole',''); const materialRole=semanticValue(serverDefinition,'materialRole','');
  const action=serverDefinition.action??serverDefinition.semanticAction??'';
  const nodes=[{key:'root',primitive}];
  if(serverDefinition.label) nodes[0].text=String(serverDefinition.label);
  const slots=(standardSlots[primitive]??[]).map(([name,writer],index)=>({index,name,target:'root',writer}));
  const actions=[]; if(action) actions.push({target:'root',action,...actionEvent(sourcePrimitive)});
  if(sourcePrimitive==='FORM'||sourcePrimitive==='TOKEN_FORM') formDefinition({primitive,sourcePrimitive,serverDefinition,nodes,slots,actions,action});
  else if(sourcePrimitive==='CHOICE_LIST') choiceListDefinition({serverDefinition,nodes,slots,actions,action});
  else if(sourcePrimitive==='SEMANTIC_RECORD') semanticRecordDefinition({serverDefinition,nodes,slots,actions,action});

  // Root diagnostic identity survives rich primitive composition. These are
  // observation/debug identities only; authoritative state remains server-side.
  const version=definitionVersion(serverDefinition);
  const root=nodes.find((node)=>node.key==='root') ?? nodes[0];
  if(primitive==='list'&&action) root.collectionActionable=true;
  if(styleRole) root.className=[root.className,`wui-${classToken(styleRole)}`].filter(Boolean).join(' ');
  root.attrs={...(root.attrs??{}),'data-wire-definition':serverDefinition.definitionKey??`${serverDefinition.definitionId}@${version}`,'data-wire-profile':String(semanticProfile),'data-wire-render-profile':String(renderProfile)};
  const diagnostic={
    'data-wire-semantic':refToken(semanticValue(serverDefinition,'semanticElementRef',null)),
    'data-wire-projection':refToken(semanticValue(serverDefinition,'projectionRef',null)),
    'data-wire-component':refToken(semanticValue(serverDefinition,'componentRef',null)),
    'data-wire-material-role':materialRole||null,
    'data-wire-ui-semantic-primitive':(sourcePrimitive==='SEMANTIC_RECORD'||sourcePrimitive==='SEMANTIC_COLLECTION')?sourcePrimitive:null
  };
  for(const [name,value] of Object.entries(diagnostic)) if(value!=null&&value!=='') root.attrs[name]=String(value);
  return {
    id:serverDefinition.definitionId, version,
    definitionKey:serverDefinition.definitionKey??`${serverDefinition.definitionId}@${version}`,
    profileId:renderProfile, contentAddress:serverDefinition.contentAddress??null, releaseRef:semanticValue(serverDefinition,'releaseRef',null),
    root:'root', nodes, slots, actions,
    semantic:{ sourcePrimitive, interactionProfile:semanticProfile, semanticElementRef:semanticValue(serverDefinition,'semanticElementRef',null), projectionRef:semanticValue(serverDefinition,'projectionRef',null), componentRef:semanticValue(serverDefinition,'componentRef',null), label:serverDefinition.label??'', styleRole, materialRole, bindings:bindingsOf(serverDefinition), metadata:metadataOf(serverDefinition) }
  };
}

export function adaptServerInstance(instance) {
  const slots={...(instance?.slots??{})}; delete slots.action;
  const parsed=parseDefinitionKey(instance?.definitionKey); const definitionId=instance?.definitionId??parsed?.id;
  if(!definitionId) throw new TypeError('server instance definitionId/definitionKey is required');
  const version=definitionVersion({definitionVersion:instance?.definitionVersion??parsed?.version,version:1}); const parent=instance.parentInstanceId??instance.parentId??null;
  return {instanceId:instance.instanceId,definitionId,definitionVersion:version,definitionKey:instance.definitionKey??`${definitionId}@${version}`,parentInstanceId:parent===''?null:parent,index:instance.index,slots};
}
export function adaptServerSnapshot(snapshot){return{viewRef:snapshot.viewRef,revision:Number(snapshot.revision),releaseRef:snapshot.releaseRef??snapshot.siteReleaseRef??null,rootInstanceId:snapshot.rootInstanceId??snapshot.rootInstance,instances:(snapshot.instances??snapshot.elementInstances??[]).map(adaptServerInstance)}};
export function adaptServerPatch(patch){return{viewRef:patch.viewRef,previousRevision:Number(patch.previousRevision),newRevision:Number(patch.newRevision),releaseRef:patch.releaseRef??patch.siteReleaseRef??null,operations:(patch.operations??[]).map(op=>op.op==='CREATE_INSTANCE'&&op.instance?{...op,instance:adaptServerInstance(op.instance)}:{...op})}};
