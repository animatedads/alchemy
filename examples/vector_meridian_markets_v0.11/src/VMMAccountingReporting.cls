/* Vector Meridian Markets Ltd accounting reporting boundaries v0.11.
 *
 * Reporting views are projections over VMM's one statutory legal-entity book.
 * A desk/business-line report is never a second company or second source of
 * accounting truth.  Boundaries are immutable evidence-bearing objects from
 * Accounting Core v0.7 and are hard-pinned here to VMM + VMM-STAT.
 */

::options digits 50

::class VMMAccountingReportingBuild public
::method version class; return "0.11"
::method protocol class; return "vmm.accounting.reporting/0.11"
::method accountingReportingApi class; return "accounting.reporting/0.1"
::method accountingScopeApi class; return "accounting.scope/0.1"
::method policyRef class; return "vmm.accounting.reporting.boundary/0.11"
::method policyIdentityBase class; return "vmm-accounting-reporting-artifact/0.11"

::class VMMAccountingReportingBoundaryFactory public
::method wholeFirm class
  use strict arg boundaryId,authorityRef,effectiveFrom,evidenceArg
  return self~build(boundaryId,authorityRef,"WHOLE_FIRM",effectiveFrom,.directory~new,"whole-firm",evidenceArg)

::method institutionalSynthetics class
  use strict arg boundaryId,authorityRef,effectiveFrom,evidenceArg
  selectors=.directory~new
  selectors[.VMMAccountingDimensions~BUSINESS_LINE]=.array~of(.VMMAccountingDimensions~BUSINESS_INSTITUTIONAL_SYNTHETICS)
  return self~build(boundaryId,authorityRef,"BUSINESS_LINE",effectiveFrom,selectors,"institutional-synthetics",evidenceArg)

::method treasuryFunding class
  use strict arg boundaryId,authorityRef,effectiveFrom,evidenceArg
  selectors=.directory~new
  selectors[.VMMAccountingDimensions~BUSINESS_LINE]=.array~of(.VMMAccountingDimensions~BUSINESS_TREASURY_FUNDING)
  return self~build(boundaryId,authorityRef,"BUSINESS_LINE",effectiveFrom,selectors,"treasury-funding",evidenceArg)

::method collateralCustody class
  use strict arg boundaryId,authorityRef,effectiveFrom,evidenceArg
  selectors=.directory~new
  selectors[.VMMAccountingDimensions~BUSINESS_LINE]=.array~of(.VMMAccountingDimensions~BUSINESS_INSTITUTIONAL_SYNTHETICS)
  selectors[.VMMAccountingDimensions~ACCOUNTING_FUNCTION]=.array~of(.VMMAccountingDimensions~FUNCTION_COLLATERAL_CUSTODY)
  return self~build(boundaryId,authorityRef,"ACCOUNTING_FUNCTION",effectiveFrom,selectors,"collateral-custody",evidenceArg)

::method closeout class
  use strict arg boundaryId,authorityRef,effectiveFrom,evidenceArg
  selectors=.directory~new
  selectors[.VMMAccountingDimensions~BUSINESS_LINE]=.array~of(.VMMAccountingDimensions~BUSINESS_INSTITUTIONAL_SYNTHETICS)
  selectors[.VMMAccountingDimensions~ACCOUNTING_FUNCTION]=.array~of(.VMMAccountingDimensions~FUNCTION_CLOSEOUT)
  return self~build(boundaryId,authorityRef,"ACCOUNTING_FUNCTION",effectiveFrom,selectors,"closeout",evidenceArg)

::method xva class
  use strict arg boundaryId,authorityRef,effectiveFrom,evidenceArg
  selectors=.directory~new
  selectors[.VMMAccountingDimensions~BUSINESS_LINE]=.array~of(.VMMAccountingDimensions~BUSINESS_INSTITUTIONAL_SYNTHETICS)
  selectors[.VMMAccountingDimensions~ACCOUNTING_FUNCTION]=.array~of(.VMMAccountingDimensions~FUNCTION_XVA)
  return self~build(boundaryId,authorityRef,"ACCOUNTING_FUNCTION",effectiveFrom,selectors,"xva",evidenceArg)

::method build class private
  use strict arg boundaryId,authorityRef,reportType,effectiveFrom,selectors,boundaryKind,evidenceArg
  if boundaryId~string~strip="" then raise syntax 88.900 array("VMM accounting reporting boundary id required")
  if authorityRef~string~strip="" then raise syntax 88.900 array("VMM accounting reporting authority required")
  if evidenceArg==.nil | \evidenceArg~isA(.Array) | evidenceArg~items=0 then raise syntax 88.900 array("VMM accounting reporting evidence required")
  metadata=.directory~new
  metadata["vmm.reportingBoundaryProtocol"]=.VMMAccountingReportingBuild~protocol
  metadata["vmm.reportingBoundaryOwner"]=.VMMAccountingBuild~legalEntity
  metadata["vmm.reportingBoundaryKind"]=boundaryKind
  identity=.VMMAccountingReportingBuild~policyIdentityBase||":"||boundaryKind
  return .AccountingReportingBoundary~new(boundaryId,authorityRef,reportType,effectiveFrom,"",.array~of(.VMMAccountingBuild~legalEntity),.array~of(.VMMAccountingPersistenceBuild~bookId),selectors,.VMMAccountingReportingBuild~policyRef,identity,evidenceArg,metadata)

::class VMMAccountingReportingService public
::method init
  expose engine
  use strict arg engine
  if engine==.nil | \engine~isA(.AccountingEngine) then raise syntax 88.900 array("AccountingEngine required")
  if engine~legalEntityId<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("VMM reporting cannot adopt another legal entity book",engine~legalEntityId)
  if engine~book~bookId<>.VMMAccountingPersistenceBuild~bookId then raise syntax 88.900 array("VMM reporting requires VMM statutory book",engine~book~bookId)

::method view
  expose engine
  use strict arg boundary,startDate="",endDate=""
  self~assertBoundary(boundary)
  return engine~reportingView(boundary,startDate,endDate)

::method assertBoundary private
  use strict arg boundary
  if boundary==.nil | \boundary~isA(.AccountingReportingBoundary) then raise syntax 88.900 array("AccountingReportingBoundary required")
  entities=boundary~includedLegalEntities
  if entities~items<>1 | entities[1]<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("VMM reporting boundary legal entity is not exact VMM")
  books=boundary~includedBookIds
  if books~items<>1 | books[1]<>.VMMAccountingPersistenceBuild~bookId then raise syntax 88.900 array("VMM reporting boundary book is not exact VMM-STAT")
  if boundary~reportingAuthorityRef~string~strip="" then raise syntax 88.900 array("VMM reporting boundary authority required")
  evidence=boundary~evidenceRefs
  if evidence~items=0 then raise syntax 88.900 array("VMM reporting boundary evidence required")
  if boundary~reportingPolicyRef<>.VMMAccountingReportingBuild~policyRef then raise syntax 88.900 array("VMM reporting boundary policy ref mismatch")
  identity=boundary~reportingPolicyIdentity
  prefix=.VMMAccountingReportingBuild~policyIdentityBase||":"
  if identity~length<prefix~length | identity~left(prefix~length)<>prefix then raise syntax 88.900 array("VMM reporting boundary policy identity mismatch")
  metadata=boundary~metadata
  if \metadata~hasIndex("vmm.reportingBoundaryProtocol") | metadata["vmm.reportingBoundaryProtocol"]<>.VMMAccountingReportingBuild~protocol then raise syntax 88.900 array("VMM reporting boundary protocol evidence missing")
  if \metadata~hasIndex("vmm.reportingBoundaryOwner") | metadata["vmm.reportingBoundaryOwner"]<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("VMM reporting boundary owner mismatch")
  return .true

::requires "VMMAccountingPersistence.cls"
