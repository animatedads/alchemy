/* Conservative MVS/TK5 semantic states built only from observed 3270 evidence.
 *
 * These states describe what the terminal currently presents.  They do not
 * grant authority to enter credentials, send AIDs, issue TSO commands or infer
 * guest/control-plane health.  The first four states below are grounded in
 * live ED209Z/ED209ZZ x3270-family qualification evidence retained by the MVS
 * Intention work.  Candidate12 also uses the exact TK5 ISPF Primary Option
 * Menu exemplar retained in the TK5 Introduction and User Manual; this is
 * reference evidence, not a claim that the manual itself is live authority.
 */
::class MVS3270KnownStates public

::method catalog class
  catalog = .KnownStateCatalog~new

  welcome = .KnownTerminalState~new("HERCULES.TK5.WELCOME_PANEL", "Hercules/TK5 3270 welcome panel", "Observed Hercules/TK5 terminal attachment panel before RESET/CLEAR transitions to VTAM/TSO", "TERMINAL_MACHINE")
  welcome~addCriterion(.KnownStateCriterion~new("welcome_3270", "CAPABILITY", "IBM_3270"))
  welcome~addCriterion(.KnownStateCriterion~new("welcome_hercules", "ANY_ROW_CONTAINS_CI", "Hercules Version"))
  welcome~addCriterion(.KnownStateCriterion~new("welcome_mvs38", "ANY_ROW_CONTAINS_CI", "The MVS 3.8j"))
  welcome~addCriterion(.KnownStateCriterion~new("welcome_tk5", "ANY_ROW_CONTAINS_CI", "Tur(n)key System"))
  ignore = catalog~register(welcome)

  logon = .KnownTerminalState~new("MVS.TSO.LOGON_PROMPT", "TSO logon prompt", "Observed TSO logon panel containing Logon ===>", "TERMINAL_MACHINE")
  logon~addCriterion(.KnownStateCriterion~new("logon_3270", "CAPABILITY", "IBM_3270"))
  logon~addCriterion(.KnownStateCriterion~new("logon_prompt", "ANY_ROW_CONTAINS_CI", "Logon ===>"))
  ignore = catalog~register(logon)

  password = .KnownTerminalState~new("MVS.TSO.PASSWORD_PROMPT", "TSO current-password prompt", "Observed TK5 prompt family ENTER CURRENT PASSWORD FOR <userid>-; recognition never exposes or supplies the password", "TERMINAL_MACHINE")
  password~addCriterion(.KnownStateCriterion~new("password_3270", "CAPABILITY", "IBM_3270"))
  password~addCriterion(.KnownStateCriterion~new("password_prompt", "ANY_ROW_CONTAINS_CI", "ENTER CURRENT PASSWORD FOR "))
  ignore = catalog~register(password)

  ready = .KnownTerminalState~new("MVS.TSO.READY", "TSO READY command state", "Observed authenticated TSO command state; requires a complete row whose trimmed value is exactly READY", "TERMINAL_MACHINE")
  ready~addCriterion(.KnownStateCriterion~new("ready_3270", "CAPABILITY", "IBM_3270"))
  ready~addCriterion(.KnownStateCriterion~new("ready_exact", "ANY_ROW_EQUALS_CI", "READY"))
  ignore = catalog~register(ready)

  ispf = .KnownTerminalState~new("MVS.ISPF.PRIMARY_OPTION_MENU", "TK5 ISPF primary option menu", "Reference-backed TK5 ISPF Primary Option Menu; recognition is observation only and grants no PF/AID authority", "TERMINAL_MACHINE")
  ispf~addCriterion(.KnownStateCriterion~new("ispf_3270", "CAPABILITY", "IBM_3270"))
  ispf~addCriterion(.KnownStateCriterion~new("ispf_title", "ANY_ROW_CONTAINS_CI", "ISPF primary option menu"))
  ispf~addCriterion(.KnownStateCriterion~new("ispf_option", "ANY_ROW_CONTAINS_CI", "Option ===>"))
  ispf~addCriterion(.KnownStateCriterion~new("ispf_end", "ANY_ROW_CONTAINS_CI", "Enter END command to terminate ISPF."))
  ignore = catalog~register(ispf)

  return catalog

::requires "TerminalCore.cls"
