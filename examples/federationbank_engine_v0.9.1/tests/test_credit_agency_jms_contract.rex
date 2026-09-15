req = .FederationBankCreditScoreRequest~new("REQ-1", "CORR-1", "CUST-1", "Example Customer", "1980-01-01", "SW1A 1AA", "OFFSHORE_CURRENT", "GBP", .DateTime~new)
codec = .FederationBankJmsCreditAgencyCodec~new
r = codec~requestMessage(req)
call must r, "encode credit request"
msg = r~value
call assert msg~isA(.JMSBridgeMessage), "request is a JMS bridge message"
call assert msg~bodyType = "TEXT", "JMS bridge dev6 outbound body is text"
call assert msg~headers["schema"] = "federationbank.credit-score.request/0.1", "wire schema explicit"
call assert msg~headers["correlationId"] = "CORR-1", "correlation id explicit"
payload = .QueueGraphPayloadCodec~new~decode(msg~body)
call assert payload["requestId"] = "REQ-1", "request id survives JMS text envelope"
call assert payload["customerReference"] = "CUST-1", "customer reference survives envelope"
call assert payload["requestedCurrency"] = "GBP", "currency survives envelope"
call assert payload["schema"] = "federationbank.credit-score.request/0.1", "payload schema explicit"
report = .FederationBankCreditScoreReport~new("REQ-1", "CORR-1", "BUREAU-1", 711, "A", "OK", .array~of("FIXTURE"))
encodedReport = codec~reportMessage(report)
call must encodedReport, "encode credit report"
decodedReport = codec~reportFromMessage(encodedReport~value)
call must decodedReport, "decode credit report"
call assert decodedReport~value~bureauReference = "BUREAU-1", "bureau reference round trips"
call assert decodedReport~value~score = 711, "score round trips"
call assert decodedReport~value~status = "OK", "status round trips"
say "PASS credit-agency JMS bridge request/report contract is black-boxed and credential-free"
exit 0
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankEngine.cls"
