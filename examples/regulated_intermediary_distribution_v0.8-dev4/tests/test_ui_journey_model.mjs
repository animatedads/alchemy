import assert from 'node:assert/strict';
import {buildRIDJourneyModel} from '../web/rid-browser.js';

let m=buildRIDJourneyModel({productFamily:'MORTGAGE',workflowState:'SUBMISSION_REQUESTED',providerStatus:'OFFERED',workStatus:'OVERDUE',completionMode:'SIGNATURE',attentionState:'OVERDUE'});
assert.equal(m.stages.find(s=>s.state==='current').key,'SIGNING');
assert.equal(m.responsibility,'Overdue intermediary action');
assert.equal(m.failed,false);

m=buildRIDJourneyModel({productFamily:'INSURANCE',providerStatus:'BOUND',workStatus:'OPEN',completionMode:'SIGNATURE',attentionState:'ACTION_REQUIRED'});
assert.equal(m.stages.find(s=>s.state==='current').key,'BOUND');
assert.equal(m.responsibility,'Intermediary action required');

m=buildRIDJourneyModel({productFamily:'MORTGAGE',providerStatus:'DECLINED',workStatus:'OPEN',attentionState:'ACTION_REQUIRED'});
assert.equal(m.stages.find(s=>s.state==='failed').key,'DECISION');
assert.equal(m.failed,true);

m=buildRIDJourneyModel({productFamily:'INVESTMENT',workflowState:'RECOMMENDED',providerStatus:'',workStatus:'OPEN',attentionState:'ACTION_REQUIRED'});
assert.equal(m.stages.find(s=>s.state==='current').key,'SUITABILITY');

console.log('PASS product-specific RID journey model remains presentation over authoritative case/work/provider fields');
