/* Federation RID browser workspace-context binder v0.7. */
export class RIDWorkspaceAuthorityMirror {
  constructor({workspaceRef='RID.CASES'}={}) {
    this.workspaceRef=workspaceRef; this.queryRevision=0; this.scopeRevision=0;
    this.orderRevision=0; this.selectionRevision=0; this.resultRevision=0; this.resultQueryRevision=0; this.resultScopeRevision=0; this.resultOrderRevision=0; this.selectedCaseId=null; this.detailVisible=false;
  }
  observeSnapshot(snapshot={}) {
    for(const i of snapshot.elementInstances??snapshot.instances??[]) this.#instance(i.instanceId,i.slots??{});
    return this.workspaceContext();
  }
  observePatch(patch={}) {
    for(const op of patch.operations??[]) {
      if(op.op==='SET_SLOT') this.#slot(op.instanceId,op.slot,op.value);
      else if(op.op==='CREATE_INSTANCE'&&op.instance) this.#instance(op.instance.instanceId,op.instance.slots??{});
      else if(op.op==='DESTROY_INSTANCE'&&op.instanceId==='case-detail'){this.selectedCaseId=null;this.detailVisible=false;}
    }
    return this.workspaceContext();
  }
  workspaceContext(){return Object.freeze({workspaceRef:this.workspaceRef,queryRevision:Number(this.queryRevision),scopeRevision:Number(this.scopeRevision),orderRevision:Number(this.orderRevision),selectionRevision:Number(this.selectionRevision),resultRevision:Number(this.resultRevision),resultQueryRevision:Number(this.resultQueryRevision),resultScopeRevision:Number(this.resultScopeRevision),resultOrderRevision:Number(this.resultOrderRevision),selectedIds:this.detailVisible&&this.selectedCaseId?[String(this.selectedCaseId)]:[]});}
  #instance(id,slots){
    if(id==='case-table') for(const k of ['queryRevision','scopeRevision','orderRevision','selectionRevision','resultRevision','resultQueryRevision','resultScopeRevision','resultOrderRevision']) if(slots[k]!=null)this[k]=Number(slots[k]);
    if(id==='case-detail'){if(slots.caseId!=null&&String(slots.caseId))this.selectedCaseId=String(slots.caseId);if(slots.visible!=null)this.detailVisible=Boolean(slots.visible);}
  }
  #slot(id,slot,value){
    if(id==='case-table'&&['queryRevision','scopeRevision','orderRevision','selectionRevision','resultRevision','resultQueryRevision','resultScopeRevision','resultOrderRevision'].includes(String(slot))){this[String(slot)]=Number(value);return;}
    if(id==='case-detail'){if(slot==='caseId')this.selectedCaseId=value==null||value===''?null:String(value);else if(slot==='visible')this.detailVisible=Boolean(value);}
  }
}
export function bindRIDWorkspaceActions({renderer,runtime,comms,workspaceRef='RID.CASES'}){
  if(!renderer||!runtime||!comms)throw new TypeError('renderer, runtime and comms are required');
  const mirror=new RIDWorkspaceAuthorityMirror({workspaceRef});
  comms.on('UI_VIEW_SNAPSHOT',p=>mirror.observeSnapshot(p)); comms.on('UI_VIEW_PATCH',p=>mirror.observePatch(p));
  renderer.setActionSink(({instanceId,action,detail={}})=>void runtime.sendSemanticAction(action,{instanceId,detail:{...detail,workspaceContext:mirror.workspaceContext()}}));
  return mirror;
}
