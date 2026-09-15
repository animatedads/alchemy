# Alchemy Report changelog

## 0.2

- customerHumanForm drops claims that touch UNKNOWN privacy
- markStaleIfDigestDiffers before seal
- ReportTransformRegistry — unnamed transforms cannot seal
- ReportAggregate — member-set fingerprint for metrics
- extra regressions: stale, projection, registry, aggregate, compile_smoke

## 0.1

- ReportDocument / Claim / Binding / Section / Trail
- seal + canSeal + groundAll
- humanForm / machineForm
- fail-closed FACT without source
## 0.3
- ReportEvidenceAdapter: Legal / Civic / host / NOTAM / Interaction Event from directories
- refuses missing identity fields
- adapter_flylo_report example


## 0.4
- ReportSealDigest prefers .SHA512 from oorexx_crypto when loaded
- no ::requires crypto; standalone fallback FINGERPRINT/1
- seal() uses ReportSealDigest

## 0.5
- Domain evidence adapters moved out of AlchemyReport.cls
- aviation NOTAM adapter is FlyLo-only
- core transform registry starts empty

## 0.6
- sourceKind is an open token; NOTAM_AIXM is not a core enum
- insurance example loads host+legal+civic only
- test_core_has_no_notam_class

## 0.7
- machineTrace / points index
- bank ReportCollateralAdapter
- sourceKind remains open

## 0.8
- accounting adapters: journal, GL posting, period
- P&L example with member-set aggregate

## 0.9
- hidePrivacy / hide(FINANCIAL) on customer projection
- ReportJournalBalance DR=CR check in accounting adapter

## 0.10
- WLU adapters: reservation, settlement, hierarchy node, price-book (DERIVED only)

## 0.11
- ReportCodec load/save machineForm round-trip
- WLU hierarchy reflectedWork is not additive

## 0.12
- Queue Fabric adapters: queue, work, disposition, UOW, journal
- logging event adapter

## 0.13
- ReportMathsMixin / ReportCryptoCheckMixin
- ReportDocumentChecked subclass inherits both
- core ReportDocument unchanged

## 0.14
- ReportMathsMixin uses .Maths / .MathClaim~equals / prove
- no homemade NUMERIC DIGITS addition
- test_maths_mixin SKIP if Maths absent
