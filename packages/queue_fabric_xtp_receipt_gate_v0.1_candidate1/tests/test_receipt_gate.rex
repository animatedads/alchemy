/* Package-local contract mocks: NEVER production authentication. */
wire=.MockWire~new
verifier=.MockVerifier~new
gate=.QueueXtpReceiptGate~new(wire,verifier,.QueueOperationResult)
env=.TestEnvelope~new('T1','SRC','DST','ORDERS')
r=gate~deliver('DST','RCV',env,'principal')
call check \r~ok & r~code='XTP_RECEIPT_UNVERIFIED', 'XTP ACK not durable receipt'
verifier~receipt=.TestReceipt~new('T1','SRC','ORDERS','P42','TIME1',.false)
r=gate~deliver('DST','RCV',env,'principal')
call check r~ok & r~value~transferId='T1', 'verified durable receipt'
verifier~receipt=.TestReceipt~new('T1','SRC','ORDERS','P42','TIME1',.true)
r=gate~deliver('DST','RCV',env,'principal')
call check r~ok & r~value~duplicate, 'idempotent duplicate'
verifier~receipt=.TestReceipt~new('OTHER','SRC','ORDERS','P42','TIME1',.false)
r=gate~deliver('DST','RCV',env,'principal')
call check \r~ok & r~code='XTP_RECEIPT_MISMATCH', 'wrong transfer'
verifier~receipt=.TestReceipt~new('T1','SRC','OTHER','P42','TIME1',.false)
r=gate~deliver('DST','RCV',env,'principal')
call check \r~ok & r~code='XTP_RECEIPT_MISMATCH', 'wrong queue'
verifier~receipt=.TestReceipt~new('T1','OTHER','ORDERS','P42','TIME1',.false)
r=gate~deliver('DST','RCV',env,'principal')
call check \r~ok & r~code='XTP_RECEIPT_MISMATCH', 'wrong manager'
verifier~receipt=.TestReceipt~new('T1','SRC','ORDERS','','TIME1',.false)
r=gate~deliver('DST','RCV',env,'principal')
call check \r~ok & r~code='XTP_RECEIPT_UNVERIFIED', 'missing durable marker'
wire~successful=.false
r=gate~deliver('DST','RCV',env,'principal')
call check \r~ok & r~code='XTP_DELIVERY_UNCERTAIN', 'XTP DIAG never durable reply'
wire~successful=.true
verifier~accepted=.false
r=gate~deliver('DST','RCV',env,'principal')
call check \r~ok & r~code='XTP_RECEIPT_UNVERIFIED', 'verifier rejection'
verifier~accepted=.true
previous=wire~calls
r=gate~deliver('OTHER','RCV',env,'principal')
call check \r~ok & r~code='DESTINATION_MANAGER_MISMATCH' & wire~calls=previous, 'destination preflight'
r=gate~deliver('DST','',env,'principal')
call check \r~ok & r~code='INVALID_CHANNEL_IDENTITY' & wire~calls=previous, 'empty channel preflight'
say 'PASS XTP receipt gate 11 contract assertions'
exit 0
::routine check
  use arg yes, label
  if yes then return
  say 'FAIL:' label
  exit 1
::class QueueOperationResult public
::attribute ok get
::attribute code get
::attribute value get
::method init
  expose ok code value
  use arg ok,code,value=.nil,detail=''
::method success class
  use arg value=.nil,detail=''
  return self~new(.true,'OK',value,detail)
::method failure class
  use arg code,detail=''
  return self~new(.false,code)
::class TestEnvelope public
::attribute transferId get
::attribute sourceManager get
::attribute destinationManager get
::attribute destinationQueue get
::method init
  expose transferId sourceManager destinationManager destinationQueue
  use arg transferId,sourceManager,destinationManager,destinationQueue
::class TestReceipt public
::attribute transferId get
::attribute sourceManager get
::attribute queueName get
::attribute packageId get
::attribute acceptedAt get
::attribute duplicate get
::method init
  expose transferId sourceManager queueName packageId acceptedAt duplicate
  use arg transferId,sourceManager,queueName,packageId,acceptedAt,duplicate
::class MockWire public
::attribute successful
::attribute calls
::method init
  expose successful calls
  successful=.true
  calls=0
::method deliver
  expose successful calls
  use arg remoteManager,remoteChannel,envelope,principal
  calls+=1
  if successful then return .QueueOperationResult~success('XTP_ONLY_ACK')
  return .QueueOperationResult~failure('DIAG_REFUSED')
::class MockVerifier public
::attribute receipt
::attribute accepted
::method init
  expose receipt accepted
  receipt=.nil
  accepted=.true
::method verifyDurableReceipt
  expose receipt accepted
  use arg response,remoteManager,remoteChannel,envelope,principal
  if response \= 'XTP_ONLY_ACK' | \accepted then return .QueueOperationResult~failure('NOT_AUTHENTICATED')
  if receipt == .nil then return .QueueOperationResult~failure('NOT_COMMITTED')
  return .QueueOperationResult~success(receipt)
::requires 'QueueXtpReceiptGate.cls'
