e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-ALL","POLICY-ALL")
mb=.FederationBankMerchantBank~new
mb~registerRelationship(.MBMerchantRelationship~new("BRK-RET-0002","CLIENT-2","RETAIL-SUBJECT-CUST-002","LINK-AUTH-22"))
mb~createPortfolio("PF-2","CLIENT-2","AUD","BRK-RET-0002")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-X","1","CFD","XAU-AUD","AUD","CASH",e))
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-Y","1","CFD","ASX200","AUD","CASH",e))
mb~bookTrade(.MBDerivativeTrade~new("TX","PF-2","CLIENT-2","CFD","LONG","AUD",900000,0,0,"",1,"XAU-AUD","CFD-X","XAU-AUD"))
mb~bookTrade(.MBDerivativeTrade~new("TY","PF-2","CLIENT-2","CFD","SHORT","AUD",100000,0,0,"",1,"ASX200","CFD-Y","ASX200"))
call assertEq 9000,mb~portfolioConcentrationBps("PF-2"),"90 percent concentration"
mb~recordMarketEvidence(.MBMarketEvidence~new("MX","MKT-AUTH","XAU-AUD","20260826T082100","AUD",1,"CURRENT"))
mb~recordMarketEvidence(.MBMarketEvidence~new("MY","MKT-AUTH","ASX200","20260826T082100","AUD",1,"CURRENT"))
mb~recordTradeMark(.MBTradeMark~new("MKX","TX","20260826T082100","AUD",500000,25000,900000,"MX"))
mb~recordTradeMark(.MBTradeMark~new("MKY","TY","20260826T082100","AUD",100000,-5000,100000,"MY"))
v=mb~createPortfolioValuation("VAL-2","PF-2","20260826T082100")
policy=.MBRiskPolicy~new("RISK-6X-CONC70",6,0,3600,7000)
a=mb~assessMargin("ASS-2","PF-2",v,policy,1000000,"20260826T082101")
call assertEq "CONCENTRATION_BREACH",a~state,"policy concentration breach"
call assertEq 9000,a~concentrationBps,"concentration evidence carried"

-- A looser policy makes the same facts compliant.
policy2=.MBRiskPolicy~new("RISK-6X-CONC95",6,0,3600,9500)
a2=mb~assessMargin("ASS-3","PF-2",v,policy2,1000000,"20260826T082102")
call assertEq "COMPLIANT",a2~state,"same facts accepted by explicit policy"
s=mb~positionSummaryForRelationship("BRK-RET-0002")
call assertEq "BRK-RET-0002",s~relationshipId,"summary relationship"
call assertEq "AUD",s~currency,"summary currency"
call assertEq 600000,s~netMarketValue,"summary merchant market value"
call assertEq 20000,s~unrealisedPnL,"summary pnl"
call assertEq 2,s~positionCount,"summary position count"
call assertEq "FEDERATION_BROKERAGE_POSITION_AUTHORITY",s~sourceAuthority,"summary source authority"

say "PASS test_risk_concentration_summary"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
