/* Vector Meridian Markets Ltd durable accounting integration v0.11.
 *
 * Accounting Core v0.4 owns the append-only accounting store format. VMM owns
 * only the legal-entity bootstrap/recovery rules and its accounting policy
 * catalogue. Recovery never reconstructs operational trading/synthetic truth;
 * it reconstructs only VMM's posted accounting truth.
 */

::options digits 50

::class VMMAccountingPersistenceBuild public
::method version class; return "0.11"
::method protocol class; return "vmm.accounting.persistence/0.11"
::method storeApi class; return "accounting.store/0.1"
::method bookId class; return "VMM-STAT"
::method reportingBasis class; return "ENTITY_GAAP"

::class VMMAccountingStore public
::method createEngine class
  use strict arg path,period
  if period==.nil | \period~isA(.AccountingPeriod) then raise syntax 88.900 array("AccountingPeriod required")
  store=.AccountingFileStore~new(path)
  book=store~createBook(.VMMAccountingBuild~legalEntity,.VMMAccountingPersistenceBuild~bookId,.VMMAccountingPersistenceBuild~reportingBasis)
  engine=.AccountingEngine~new(book~legalEntityId,book~bookId,book~reportingBasis,book)
  .VMMAccountingPolicy~configureEngine(engine,period)
  return engine

::method recoverEngine class
  use strict arg path
  store=.AccountingFileStore~new(path)
  book=store~recoverBook
  self~assertVMMBook(book)
  engine=.AccountingEngine~new(book~legalEntityId,book~bookId,book~reportingBasis,book)
  .VMMAccountingPolicy~registerPolicies(engine)
  return engine

::method recoverReplayOnlyEngine class
  use strict arg path
  store=.AccountingFileStore~new(path)
  book=store~recoverBook
  self~assertVMMBook(book)
  /* Deliberately no policy catalogue: Accounting Core must resolve exact event
   * replay/conflict from recovered journal identity before policy dispatch. */
  return .AccountingEngine~new(book~legalEntityId,book~bookId,book~reportingBasis,book)

::method assertVMMBook class private
  use strict arg book
  if book==.nil | \book~isA(.AccountingBook) then raise syntax 88.900 array("AccountingBook required")
  if book~legalEntityId<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("Recovered accounting book is not VMM",book~legalEntityId)
  if book~bookId<>.VMMAccountingPersistenceBuild~bookId then raise syntax 88.900 array("Recovered accounting book ID is not VMM statutory book",book~bookId)
  if book~reportingBasis<>.VMMAccountingPersistenceBuild~reportingBasis then raise syntax 88.900 array("Recovered accounting reporting basis mismatch",book~reportingBasis)
  return .true

::class VMMAccountingPeriodControl public
::method close class
  use strict arg engine,periodId,actorRef,reason,evidenceArg,occurredAt
  self~assertAuthority(engine,actorRef,reason,evidenceArg,occurredAt)
  return engine~book~transitionPeriod(periodId,"CLOSED",actorRef,reason,evidenceArg,occurredAt)

::method reopen class
  use strict arg engine,periodId,actorRef,reason,evidenceArg,occurredAt
  self~assertAuthority(engine,actorRef,reason,evidenceArg,occurredAt)
  return engine~book~transitionPeriod(periodId,"OPEN",actorRef,reason,evidenceArg,occurredAt)

::method lock class
  use strict arg engine,periodId,actorRef,reason,evidenceArg,occurredAt
  self~assertAuthority(engine,actorRef,reason,evidenceArg,occurredAt)
  return engine~book~transitionPeriod(periodId,"LOCKED",actorRef,reason,evidenceArg,occurredAt)

::method assertAuthority class private
  use strict arg engine,actorRef,reason,evidenceArg,occurredAt
  if engine==.nil | \engine~isA(.AccountingEngine) then raise syntax 88.900 array("AccountingEngine required")
  if engine~legalEntityId<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("VMM accounting period control legal entity mismatch")
  if actorRef~string~strip="" then raise syntax 88.900 array("VMM accounting period transition actor required")
  if reason~string~strip="" then raise syntax 88.900 array("VMM accounting period transition reason required")
  if occurredAt~string~strip="" then raise syntax 88.900 array("VMM accounting period transition occurrence time required")
  if evidenceArg==.nil | \evidenceArg~isA(.Array) | evidenceArg~items=0 then raise syntax 88.900 array("VMM accounting period transition evidence required")
  return .true

::requires "AccountingPersistence.cls"
::requires "VMMAccounting.cls"
