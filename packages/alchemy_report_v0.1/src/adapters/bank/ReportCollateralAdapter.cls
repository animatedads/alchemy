/******************************************************************************/
/* Federation Bank / merchant collateral — not aviation, not insurance.       */
/******************************************************************************/
::class ReportCollateralAdapter public subclass ReportAdapterBase

::method transformId class
  return "bank.collateral.position/0.1"

::method bind class
  use arg bindingId, role, d
  self~need(d, "positionId")
  point = "BANK:COLLATERAL:" || d["positionId"]
  return .ReportBinding~new(bindingId, role, "COLLATERAL_POSITION", point,,
        self~opt(d, "digest", ""), self~opt(d, "span", ""),,
        self~opt(d, "asOf", ""), self~transformId,,
        self~opt(d, "privacyClass", "OPERATIONAL"))

::requires "../ReportAdapterBase.cls"
