::class MBSettlementAccountingFixture public
::method closeOut class
  use strict arg signedSettlement=1000,client="CLIENT-SETTLE",suffix="A"
  mb=.FederationBankMerchantBank~new
  pf="PF-SET-"||suffix; tr="TR-SET-"||suffix
  mb~createPortfolio(pf,client,"GBP")
  mb~bookTrade(.MBDerivativeTrade~new(tr,pf,client,"OPTION","LONG","GBP",1000000,1000,10000,"2026-12-31",1,"IDX-SET-"||suffix,"","IDX-SET-"||suffix,"08:00"))
  v=.MBValuationSnapshot~new("VAL-SET-"||suffix,pf,"09:00","GBP",0,0,12000000,"MKTSET-"||suffix)
  mb~recordValuation(v)
  policy=.MBRiskPolicy~new("POL-SET-"||suffix,6,0,3600)
  a=mb~assessMargin("ASS-SET-"||suffix,pf,v,policy,0,"09:01")
  c=mb~issueMarginCall("CALL-SET-"||suffix,a~assessmentId,"09:02","10:02")
  i=mb~defaultMarginCall(c~callId,"CLOSE-SET-"||suffix,"MB-RISK-AUTH","10:03")
  mkt="MKT-SET-"||suffix
  mb~recordMarketEvidence(.MBMarketEvidence~new(mkt,"EXCHANGE-SETTLE","IDX-SET-"||suffix,"10:04","GBP",1000,"CURRENT"))
  results=.directory~new
  results[tr]=.MBCloseOutTradeResult~new("RES-SET-"||suffix,tr,mkt,100,signedSettlement,"MB-CLOSEOUT-AUTH")
  execId="EXEC-SET-"||suffix
  x=mb~executeCloseOut(i~instructionId,execId,results,"10:05","MB-CLOSEOUT-AUTH")
  o=mb~createCloseOutSettlementObligation("OBL-SET-"||suffix,execId)
  d=.directory~new; d["mb"]=mb; d["portfolioId"]=pf; d["tradeId"]=tr; d["execution"]=x; d["obligation"]=o
  d["scale"]=.MBAccountingCurrencyScaleEvidence~new("GBP-2DP-"||suffix,"GBP",100,"ACCOUNTING-POLICY","ISO4217:GBP")
  return d
::requires "FederationBankMerchantAccountingProjection.cls"
