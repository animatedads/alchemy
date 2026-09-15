#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node --check "$ROOT/web/bootstrap-config.js"
node --check "$ROOT/web/merchant-wire-ui.js"
node --check "$ROOT/web/merchant-workspace-context.js"
node --test "$ROOT/tests/test_bootstrap_config.mjs"
# The live shell must not contain hard-coded Merchant/Core business commands.
if grep -Eiq 'CLOSE_POSITION|CLOSE_INTENT|TRADE\.|MARGIN_CALL|COLLATERAL_(CONTROL|REALISATION)|SETTLEMENT_REQUEST|LEDGER|accountId|debitThisAccount' "$ROOT/web/index.html" "$ROOT/web/merchant-wire-ui.js" "$ROOT/web/merchant-workspace-context.js"; then
  echo 'FAIL: live browser shell contains hard-coded domain semantics' >&2
  exit 1
fi
grep -q 'wire-ui-root' "$ROOT/web/index.html"
grep -q 'QueueFabricGatewayTransport' "$ROOT/web/merchant-wire-ui.js"
grep -q 'MaterialController' "$ROOT/web/merchant-wire-ui.js"
grep -q 'bootstrapUrl' "$ROOT/web/index.html"
grep -q "putResultMode: 'required'" "$ROOT/web/merchant-wire-ui.js"
grep -q 'Merchant Banking perimeter' "$ROOT/web/index.html"
echo 'FEDERATIONBANK MERCHANT WIRE UI PROJECTION SHELL: OK'
grep -q 'FBMerchantWireRuntimeFactory' "$ROOT/integration/FBMerchantWireUIApplication.cls"
grep -q 'FBMerchantWireUIDesignFixture' "$ROOT/integration/FBMerchantWireUIDesignFixture.cls"
grep -q 'FBMerchantWireAuthorityProjectionAdapter' "$ROOT/integration/FBMerchantWireAuthorityProjectionAdapter.cls"
grep -q 'FBMerchantWireAuthorityRuntimeFactory' "$ROOT/integration/FBMerchantWireAuthorityRuntimeFactory.cls"
grep -q 'FBMerchantWireWebGatewayService' "$ROOT/integration/FBMerchantWireWebGatewayService.cls"
grep -q 'workspaceContext' "$ROOT/web/merchant-workspace-context.js"
if grep -Eiq '~(bookTrade|bookCFDOffset|recordSettlementInstruction|recordSettlementObservation|executeRiskNeutralisation|postSettlement|proposeHedgeRemediationPlan|approveHedgeRemediationPlan|handle\()' "$ROOT/integration/FBMerchantWireAuthorityProjectionAdapter.cls"; then
  echo 'FAIL: authority projection adapter invokes Merchant/Risk/Accounting mutation surface' >&2
  exit 1
fi
if grep -Eiq 'CLOSE_POSITION|CLOSE_INTENT|TRADE\.BOOK|MARGIN_CALL|COLLATERAL_(CONTROL|REALISATION)|SETTLEMENT\.(INSTRUCT|OBSERVE|COMPLETE)|ACCOUNTING\.(POST|REVERSE)|LEDGER\.' "$ROOT/integration/FBMerchantWireUIApplication.cls"; then
  echo 'FAIL: Merchant Wire UI application exposes domain mutation semantics' >&2
  exit 1
fi
node - "$ROOT/semantic/federationbank_merchant_operations_v0.6.json" <<'NODE'
const fs=require('node:fs');
const p=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
if(p.packageId!=='FEDERATIONBANK_MERCHANT_OPERATIONS' || p.packageVersion!=='2026.09.01.1' || p.definitions.length!==12) process.exit(20);
const byKey=Object.fromEntries(p.definitions.map(d=>[d.definitionKey,d]));
for(const key of ['FBM_BOOK_QUERY@1','FBM_BOOK_TABLE@1','FBM_WORKSPACE_CONTEXT@1','FBM_BOOK_ROW@1','FBM_BOOK_OPEN@1']) if(!byKey[key]) process.exit(22);
if(!('workspaceRef' in byKey['FBM_BOOK_QUERY@1'].bindings)) process.exit(23);
if(!('semanticRowId' in byKey['FBM_BOOK_ROW@1'].bindings) || !('workspaceRef' in byKey['FBM_BOOK_ROW@1'].bindings)) process.exit(24);
if(byKey['FBM_BOOK_OPEN@1'].action!=='BOOK.OPEN') process.exit(26);
for(const slot of ['workspaceRef','selectedIdsJson','queryRevision','scopeRevision','orderRevision','selectionRevision','resultRevision','resultQueryRevision','resultScopeRevision','resultOrderRevision']) if(!(slot in byKey['FBM_WORKSPACE_CONTEXT@1'].bindings)) process.exit(27);
for(const slot of ['collectionRef','windowOffset','windowLimit','windowTotalCount','visibleRowCount','windowRevision','queryRevision','scopeRevision','orderRevision','selectionRevision','resultRevision']) if(!(slot in byKey['FBM_BOOK_TABLE@1'].bindings)) process.exit(25);
const text=JSON.stringify(p);
for(const forbidden of ['TRADE.BOOK','REMEDIATION.PLAN.APPROVE','SETTLEMENT.INSTRUCT','SETTLEMENT.OBSERVE','ACCOUNTING.POST','COLLATERAL.REALISE','LEDGER.POST']) {
  if(text.includes(forbidden)) process.exit(21);
}
NODE
