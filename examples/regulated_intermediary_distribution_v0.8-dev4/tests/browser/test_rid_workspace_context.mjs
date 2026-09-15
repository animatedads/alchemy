import assert from 'node:assert/strict';
import {RIDWorkspaceAuthorityMirror} from '../../web/rid-browser-runtime.js';
const m=new RIDWorkspaceAuthorityMirror();
m.observeSnapshot({elementInstances:[{instanceId:'case-table',slots:{queryRevision:3,scopeRevision:2,orderRevision:4,selectionRevision:0,resultRevision:7,resultQueryRevision:3,resultScopeRevision:2,resultOrderRevision:4}},{instanceId:'case-detail',slots:{visible:false}}]});
assert.deepEqual(m.workspaceContext(),{workspaceRef:'RID.CASES',queryRevision:3,scopeRevision:2,orderRevision:4,selectionRevision:0,resultRevision:7,resultQueryRevision:3,resultScopeRevision:2,resultOrderRevision:4,selectedIds:[]});
m.observePatch({operations:[{op:'SET_SLOT',instanceId:'case-table',slot:'selectionRevision',value:1},{op:'SET_SLOT',instanceId:'case-detail',slot:'caseId',value:'CASE-W'},{op:'SET_SLOT',instanceId:'case-detail',slot:'visible',value:true}]});
assert.deepEqual(m.workspaceContext(),{workspaceRef:'RID.CASES',queryRevision:3,scopeRevision:2,orderRevision:4,selectionRevision:1,resultRevision:7,resultQueryRevision:3,resultScopeRevision:2,resultOrderRevision:4,selectedIds:['CASE-W']});
m.observePatch({operations:[{op:'SET_SLOT',instanceId:'case-detail',slot:'visible',value:false}]});assert.deepEqual(m.workspaceContext().selectedIds,[]);
console.log('PASS browser mirrors server-issued query/selection/result command authority');
