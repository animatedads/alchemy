/* Queue Fabric XTP durable receipt gate candidate1.
 * Transport acknowledgment is not remote Queue Fabric durable acceptance.
 * No ::requires: parent resolves exact .QueueOperationResult as resultClass.
 * The verifier must authenticate the remote manager/channel/principal,
 * queue.transport/2 transcript and committed receiver transfer receipt.
 */
::class QueueXtpReceiptGate public
::method init
  expose wireTransport receiptVerifier resultClass
  use strict arg senderTransport, verifier, resultClass
  if senderTransport == .nil | verifier == .nil then raise syntax 88.900 array('XTP receipt gate requires transport and verifier')
  if \senderTransport~hasMethod('DELIVER') then raise syntax 88.900 array('XTP transport missing DELIVER')
  if \verifier~hasMethod('VERIFYDURABLERECEIPT') then raise syntax 88.900 array('XTP verifier missing VERIFYDURABLERECEIPT')
  if resultClass == .nil | \resultClass~hasMethod('SUCCESS') | \resultClass~hasMethod('FAILURE') then raise syntax 88.900 array('XTP receipt gate needs QueueOperationResult class')
  wireTransport = senderTransport
  receiptVerifier = verifier
  resultClass = resultClass
::method deliver
  expose wireTransport receiptVerifier resultClass
  use strict arg remoteManager, remoteChannel, envelope, principal
  if envelope == .nil then return resultClass~failure('INVALID_TRANSMISSION_ENVELOPE')
  if \envelope~hasMethod('TRANSFERID') | \envelope~hasMethod('DESTINATIONMANAGER') | \envelope~hasMethod('DESTINATIONQUEUE') | \envelope~hasMethod('SOURCEMANAGER') then return resultClass~failure('INVALID_TRANSMISSION_ENVELOPE')
  if envelope~transferId = '' | envelope~destinationQueue = '' then return resultClass~failure('INVALID_TRANSMISSION_ENVELOPE')
  if envelope~destinationManager \= remoteManager then return resultClass~failure('DESTINATION_MANAGER_MISMATCH')
  if remoteChannel = '' | principal = '' then return resultClass~failure('INVALID_CHANNEL_IDENTITY')
  signal on syntax name transportError
  wireResult = wireTransport~deliver(remoteManager, remoteChannel, envelope, principal)
  signal off syntax
  if wireResult == .nil then return resultClass~failure('XTP_DELIVERY_UNCERTAIN', 'missing transport result')
  if \wireResult~hasMethod('OK') | \wireResult~hasMethod('VALUE') then return resultClass~failure('XTP_DELIVERY_UNCERTAIN', 'invalid transport result')
  if \wireResult~ok then return resultClass~failure('XTP_DELIVERY_UNCERTAIN', 'transport did not confirm a durable queue result')
  signal on syntax name verifierError
  proofResult = receiptVerifier~verifyDurableReceipt(wireResult~value, remoteManager, remoteChannel, envelope, principal)
  signal off syntax
  if proofResult == .nil then return resultClass~failure('XTP_RECEIPT_UNVERIFIED', 'missing authenticated result')
  if \proofResult~hasMethod('OK') | \proofResult~hasMethod('VALUE') then return resultClass~failure('XTP_RECEIPT_UNVERIFIED', 'invalid authenticated result')
  if \proofResult~ok then return resultClass~failure('XTP_RECEIPT_UNVERIFIED', 'receiver UOW not confirmed')
  receipt = proofResult~value
  if receipt == .nil then return resultClass~failure('XTP_RECEIPT_UNVERIFIED', 'receipt absent')
  if \receipt~hasMethod('TRANSFERID') | \receipt~hasMethod('QUEUENAME') | \receipt~hasMethod('SOURCEMANAGER') | \receipt~hasMethod('PACKAGEID') | \receipt~hasMethod('ACCEPTEDAT') | \receipt~hasMethod('DUPLICATE') then return resultClass~failure('XTP_RECEIPT_UNVERIFIED', 'receipt shape incomplete')
  if receipt~transferId \= envelope~transferId then return resultClass~failure('XTP_RECEIPT_MISMATCH', 'transferId')
  if receipt~queueName \= envelope~destinationQueue then return resultClass~failure('XTP_RECEIPT_MISMATCH', 'queueName')
  if receipt~sourceManager \= envelope~sourceManager then return resultClass~failure('XTP_RECEIPT_MISMATCH', 'sourceManager')
  if receipt~packageId = '' | receipt~acceptedAt = '' then return resultClass~failure('XTP_RECEIPT_UNVERIFIED', 'no durable acceptance marker')
  return resultClass~success(receipt, 'authenticated durable receiver receipt')
transportError:
  signal off syntax
  return resultClass~failure('XTP_DELIVERY_UNCERTAIN', 'transport exception')
verifierError:
  signal off syntax
  return resultClass~failure('XTP_RECEIPT_UNVERIFIED', 'verifier exception')
