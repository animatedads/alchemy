import test from 'node:test';
import assert from 'node:assert/strict';
import { MerchantWorkspaceContextEcho } from '../web/merchant-workspace-context.js';

const MessageKind={UI_VIEW_SNAPSHOT:'UI_VIEW_SNAPSHOT',UI_VIEW_PATCH:'UI_VIEW_PATCH',UI_ACTION:'UI_ACTION'};
class FakeComms {
  constructor(){this.handlers=new Map();this.sent=[];}
  on(kind,fn){const a=this.handlers.get(kind)??[];a.push(fn);this.handlers.set(kind,a);}
  async send(kind,payload,options){this.sent.push({kind,payload,options});return {ok:true};}
  emit(kind,payload){for(const fn of this.handlers.get(kind)??[])fn(payload);}
}

test('server-issued workspace context is echoed, not invented', async()=>{
  const comms=new FakeComms();
  new MerchantWorkspaceContextEcho({comms,MessageKind}).install();
  comms.emit(MessageKind.UI_VIEW_SNAPSHOT,{elementInstances:[{instanceId:'workspace-context',slots:{workspaceRef:'FBM.BOOKS',selectedIdsJson:'["ROOT-A"]',queryRevision:2,scopeRevision:3,orderRevision:4,selectionRevision:5,resultRevision:6,resultQueryRevision:2,resultScopeRevision:3,resultOrderRevision:4}}]});
  await comms.send(MessageKind.UI_ACTION,{action:'BOOK.OPEN',detail:{clientNoise:'ignored-by-server'}});
  const ctx=comms.sent.at(-1).payload.detail.workspaceContext;
  assert.deepEqual(ctx,{workspaceRef:'FBM.BOOKS',queryRevision:2,scopeRevision:3,orderRevision:4,selectionRevision:5,selectedIds:['ROOT-A'],resultRevision:6,resultQueryRevision:2,resultScopeRevision:3,resultOrderRevision:4});
  comms.emit(MessageKind.UI_VIEW_PATCH,{operations:[{op:'SET_SLOT',instanceId:'workspace-context',slot:'resultRevision',value:7},{op:'SET_SLOT',instanceId:'workspace-context',slot:'selectedIdsJson',value:'[]'}]});
  await comms.send(MessageKind.UI_ACTION,{action:'WORKSPACE.REFRESH',detail:{}});
  assert.equal(comms.sent.at(-1).payload.detail.workspaceContext.resultRevision,7);
  assert.deepEqual(comms.sent.at(-1).payload.detail.workspaceContext.selectedIds,[]);
});
