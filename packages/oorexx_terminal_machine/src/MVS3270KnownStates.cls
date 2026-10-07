/* Conservative MVS/TK5 semantic states built only from observed 3270 evidence.
 * This is knowledge, not action authority.  Deliberately no guessed READY or
 * ISPF states are registered until environment evidence is captured for them.
 */
::class MVS3270KnownStates public

::method catalog class
  catalog = .KnownStateCatalog~new

  logon = .KnownTerminalState~new("MVS.TSO.LOGON_PROMPT", "TSO logon prompt", "Observed TSO logon panel containing Logon ===>", "TERMINAL_MACHINE")
  logon~addCriterion(.KnownStateCriterion~new("mvs3270", "CAPABILITY", "IBM_3270"))
  logon~addCriterion(.KnownStateCriterion~new("logon_prompt", "ANY_ROW_CONTAINS_CI", "Logon ===>"))
  ignore = catalog~register(logon)

  return catalog

::requires "TerminalCore.cls"
