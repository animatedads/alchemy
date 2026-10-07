/*
 * 5250 known-state + credential staging v0.1.
 *
 * This layer is intentionally outside the generic terminal core.  It knows how
 * to recognize a learned IBM i sign-on exemplar and how to consume a trusted
 * credential lease into a 5250 username/nondisplay-password field pair.
 *
 * It does NOT press Enter.  Credential staging and AID authorization remain two
 * separate actions.  The safe result contains no username, password or wire
 * bytes.
 */

::class TN5250CredentialLoginBuild public
::constant RELEASE "0.2"
::constant API_VERSION "terminal.tn5250.credential-login/0.2"

::class TN5250CredentialStageResult public
::attribute credentialReference get
::attribute stateId get
::attribute userFieldId get
::attribute passwordFieldId get
::attribute snapshot get

::method init
  expose credentialReference stateId userFieldId passwordFieldId snapshot
  use arg referenceArg, stateIdArg, userFieldIdArg, passwordFieldIdArg, snapshotArg
  credentialReference = referenceArg~string
  stateId = stateIdArg~string
  userFieldId = userFieldIdArg~string
  passwordFieldId = passwordFieldIdArg~string
  snapshot = snapshotArg~copyDetached

/* Learn a conservative known state from a live sign-on snapshot.  Exact field
 * topology comes from the exemplar; volatile server/device/news text does not.
 */
::class KnownState5250Factory public
::method ibmISignon class
  use arg snapshot, stateIdArg = "IBM_I_SIGNON", createdByArg = "HUMAN_CONFIRMED"
  if snapshot == .nil then return .TerminalResult~failure("SIGNON_NO_SNAPSHOT", "snapshot is required")
  if snapshot~terminalType \== "IBM5250" then return .TerminalResult~failure("SIGNON_WRONG_TERMINAL", snapshot~terminalType)

  found = self~findCredentialFields(snapshot)
  if \found~ok then return found
  pair = found~value
  userField = pair["user"]
  passwordField = pair["password"]

  userRow = snapshot~rowText(userField~row)
  passRow = snapshot~rowText(passwordField~row)
  if pos("USER", userRow~upper) = 0 then return .TerminalResult~failure("SIGNON_USER_LABEL_NOT_FOUND", userRow)
  if pos("PASSWORD", passRow~upper) = 0 then return .TerminalResult~failure("SIGNON_PASSWORD_LABEL_NOT_FOUND", passRow)

  state = .KnownTerminalState~new(stateIdArg, "IBM i sign-on", "IBM i sign-on panel awaiting a user profile and password.", createdByArg)
  state~addCriterion(.KnownStateCriterion~new("terminal", "TERMINAL_TYPE_EQ", "IBM5250"))
  state~addCriterion(.KnownStateCriterion~new("keyboard", "KEYBOARD_EQ", "UNLOCKED"))
  state~addCriterion(.KnownStateCriterion~new("user-label", "ROW_CONTAINS_CI", userField~row, "user"))
  state~addCriterion(.KnownStateCriterion~new("password-label", "ROW_CONTAINS_CI", passwordField~row, "password"))
  state~addCriterion(.KnownStateCriterion~new("user-input", "FIELD_AT_INPUT", userField~row, userField~column))
  state~addCriterion(.KnownStateCriterion~new("user-length", "FIELD_AT_LENGTH_EQ", userField~row || "," || userField~column, userField~length))
  state~addCriterion(.KnownStateCriterion~new("password-input", "FIELD_AT_INPUT", passwordField~row, passwordField~column))
  state~addCriterion(.KnownStateCriterion~new("password-nondisplay", "FIELD_AT_NONDISPLAY", passwordField~row, passwordField~column))
  state~addCriterion(.KnownStateCriterion~new("password-length", "FIELD_AT_LENGTH_EQ", passwordField~row || "," || passwordField~column, passwordField~length))
  state~addCriterion(.KnownStateCriterion~new("cursor-user", "CURSOR_IN_FIELD_AT", userField~row, userField~column))
  state~addExemplar(.FrozenTerminalState~new(snapshot))
  state~addAnnotation(.KnownStateAnnotation~new("learned-signon", createdByArg, "Learned from a confirmed live IBM i sign-on screen. Volatile system/device/news text is not part of the matcher.", "CONFIRMED"))
  return .TerminalResult~success(state)

::method ibmIPasswordExpiredNotice class
  use arg snapshot, stateIdArg = "IBM_I_PASSWORD_EXPIRED_NOTICE", createdByArg = "HUMAN_CONFIRMED"
  if snapshot == .nil then return .TerminalResult~failure("PASSWORD_EXPIRED_NO_SNAPSHOT", "snapshot is required")
  if snapshot~terminalType \== "IBM5250" then return .TerminalResult~failure("PASSWORD_EXPIRED_WRONG_TERMINAL", snapshot~terminalType)
  if snapshot~fields~items \== 0 then return .TerminalResult~failure("PASSWORD_EXPIRED_FIELDS_PRESENT", snapshot~fields~items)

  titleRow = self~findRowContainingCI(snapshot, "SIGN-ON INFORMATION")
  expiredRow = self~findRowContainingCI(snapshot, "PASSWORD HAS EXPIRED")
  enterRow = self~findRowContainingCI(snapshot, "PRESS ENTER TO CHANGE YOUR PASSWORD")
  if titleRow = 0 then return .TerminalResult~failure("PASSWORD_EXPIRED_TITLE_NOT_FOUND", "Sign-on Information")
  if expiredRow = 0 then return .TerminalResult~failure("PASSWORD_EXPIRED_TEXT_NOT_FOUND", "Password has expired")
  if enterRow = 0 then return .TerminalResult~failure("PASSWORD_EXPIRED_ENTER_NOT_FOUND", "Press Enter to change your password")

  state = .KnownTerminalState~new(stateIdArg, "IBM i password-expired notice", "IBM i sign-on information panel requiring Enter before password change.", createdByArg)
  state~addCriterion(.KnownStateCriterion~new("terminal", "TERMINAL_TYPE_EQ", "IBM5250"))
  state~addCriterion(.KnownStateCriterion~new("keyboard", "KEYBOARD_EQ", "UNLOCKED"))
  state~addCriterion(.KnownStateCriterion~new("fields", "FIELD_COUNT_EQ", 0))
  state~addCriterion(.KnownStateCriterion~new("title", "ROW_CONTAINS_CI", titleRow, "sign-on information"))
  state~addCriterion(.KnownStateCriterion~new("expired", "ROW_CONTAINS_CI", expiredRow, "password has expired"))
  state~addCriterion(.KnownStateCriterion~new("enter", "ROW_CONTAINS_CI", enterRow, "press enter to change your password"))
  state~addExemplar(.FrozenTerminalState~new(snapshot))
  state~addAnnotation(.KnownStateAnnotation~new("learned-password-expired-notice", createdByArg, "Confirmed IBM i sign-on continuation state after successful authentication with an expired password. No credential fields are present on this notice.", "CONFIRMED"))
  return .TerminalResult~success(state)

::method ibmIChangePassword class
  use arg snapshot, stateIdArg = "IBM_I_CHANGE_PASSWORD", createdByArg = "HUMAN_CONFIRMED"
  if snapshot == .nil then return .TerminalResult~failure("CHANGE_PASSWORD_NO_SNAPSHOT", "snapshot is required")
  if snapshot~terminalType \== "IBM5250" then return .TerminalResult~failure("CHANGE_PASSWORD_WRONG_TERMINAL", snapshot~terminalType)

  titleRow = self~findRowContainingCI(snapshot, "CHANGE PASSWORD")
  if titleRow = 0 then return .TerminalResult~failure("CHANGE_PASSWORD_TITLE_NOT_FOUND", "Change Password")

  mappedResult = self~findChangePasswordFields(snapshot)
  if \mappedResult~ok then return mappedResult
  mapped = mappedResult~value
  currentField = mapped["current"]
  newField = mapped["new"]
  verifyField = mapped["verify"]
  currentRow = currentField~row
  newRow = newField~row
  verifyRow = verifyField~row

  secretFields = .array~new
  do f over snapshot~fields
    if f~inputCapable then do
      if \f~protected then do
        if f~nonDisplay then secretFields~append(f)
      end
    end
  end
  if secretFields~items \== 3 then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_COUNT", "nondisplay input fields=" || secretFields~items)

  state = .KnownTerminalState~new(stateIdArg, "IBM i change password", "IBM i change-password panel with current, new and verification password fields.", createdByArg)
  state~addCriterion(.KnownStateCriterion~new("terminal", "TERMINAL_TYPE_EQ", "IBM5250"))
  state~addCriterion(.KnownStateCriterion~new("fields", "FIELD_COUNT_EQ", snapshot~fields~items))
  state~addCriterion(.KnownStateCriterion~new("title", "ROW_CONTAINS_CI", titleRow, "change password"))
  state~addCriterion(.KnownStateCriterion~new("current-label", "ROW_CONTAINS_CI", currentRow, "current password"))
  state~addCriterion(.KnownStateCriterion~new("new-label", "ROW_CONTAINS_CI", newRow, "new password"))
  state~addCriterion(.KnownStateCriterion~new("verify-label", "ROW_CONTAINS_CI", verifyRow, "new password (to verify)"))
  do tagged over self~passwordFieldMap(currentField, newField, verifyField)
    parse var tagged tag "=" row "," col "," len
    state~addCriterion(.KnownStateCriterion~new(tag || "-input", "FIELD_AT_INPUT", row, col))
    state~addCriterion(.KnownStateCriterion~new(tag || "-secret", "FIELD_AT_NONDISPLAY", row, col))
    state~addCriterion(.KnownStateCriterion~new(tag || "-length", "FIELD_AT_LENGTH_EQ", row || "," || col, len))
  end
  state~addExemplar(.FrozenTerminalState~new(snapshot))
  state~addAnnotation(.KnownStateAnnotation~new("learned-change-password", createdByArg, "Learned only from a structured live 5250 screen with three host-declared nondisplay input fields. Cursor position and transient operator-error text are deliberately not matcher criteria.", "CONFIRMED"))
  return .TerminalResult~success(state)

::method ibmIMainMenu class
  use arg snapshot, stateIdArg = "IBM_I_MAIN_MENU", createdByArg = "HUMAN_CONFIRMED"
  if snapshot == .nil then return .TerminalResult~failure("MAIN_MENU_NO_SNAPSHOT", "snapshot is required")
  if snapshot~terminalType \== "IBM5250" then return .TerminalResult~failure("MAIN_MENU_WRONG_TERMINAL", snapshot~terminalType)

  titleRow = self~findRowContainingCI(snapshot, "IBM I MAIN MENU")
  selectRow = self~findRowContainingCI(snapshot, "SELECT ONE OF THE FOLLOWING")
  signoffRow = self~findRowContainingCI(snapshot, "90. SIGN OFF")
  commandLabelRow = self~findRowContainingCI(snapshot, "SELECTION OR COMMAND")
  if titleRow = 0 then return .TerminalResult~failure("MAIN_MENU_TITLE_NOT_FOUND", "IBM i Main Menu")
  if selectRow = 0 then return .TerminalResult~failure("MAIN_MENU_SELECT_TEXT_NOT_FOUND", "Select one of the following")
  if signoffRow = 0 then return .TerminalResult~failure("MAIN_MENU_SIGNOFF_NOT_FOUND", "90. Sign off")
  if commandLabelRow = 0 then return .TerminalResult~failure("MAIN_MENU_COMMAND_LABEL_NOT_FOUND", "Selection or command")

  fieldResult = self~findMainMenuCommandField(snapshot)
  if \fieldResult~ok then return fieldResult
  commandField = fieldResult~value

  state = .KnownTerminalState~new(stateIdArg, "IBM i Main Menu", "IBM i MAIN menu with explicit 90=Sign off and one command/selection input field.", createdByArg)
  state~addCriterion(.KnownStateCriterion~new("terminal", "TERMINAL_TYPE_EQ", "IBM5250"))
  state~addCriterion(.KnownStateCriterion~new("keyboard", "KEYBOARD_EQ", "UNLOCKED"))
  state~addCriterion(.KnownStateCriterion~new("fields", "FIELD_COUNT_EQ", snapshot~fields~items))
  state~addCriterion(.KnownStateCriterion~new("title", "ROW_CONTAINS_CI", titleRow, "ibm i main menu"))
  state~addCriterion(.KnownStateCriterion~new("select", "ROW_CONTAINS_CI", selectRow, "select one of the following"))
  state~addCriterion(.KnownStateCriterion~new("signoff", "ROW_CONTAINS_CI", signoffRow, "90. sign off"))
  state~addCriterion(.KnownStateCriterion~new("command-label", "ROW_CONTAINS_CI", commandLabelRow, "selection or command"))
  state~addCriterion(.KnownStateCriterion~new("command-input", "FIELD_AT_INPUT", commandField~row, commandField~column))
  state~addCriterion(.KnownStateCriterion~new("command-length", "FIELD_AT_LENGTH_EQ", commandField~row || "," || commandField~column, commandField~length))
  state~addExemplar(.FrozenTerminalState~new(snapshot))
  state~addAnnotation(.KnownStateAnnotation~new("learned-main-menu", createdByArg, "Confirmed live PUB400 IBM i MAIN menu after successful password change. The explicit 90=Sign off option and command field are required before automated signoff is permitted.", "CONFIRMED"))
  return .TerminalResult~success(state)

::method findMainMenuCommandField class
  use arg snapshot
  if snapshot == .nil then return .TerminalResult~failure("MAIN_MENU_NO_SNAPSHOT", "snapshot is required")
  candidates = .array~new
  do f over snapshot~fields
    if \f~inputCapable then iterate
    if f~protected then iterate
    if f~nonDisplay then iterate
    candidates~append(f)
  end
  if candidates~items \== 1 then return .TerminalResult~failure("MAIN_MENU_COMMAND_FIELD_AMBIGUOUS", "input/display fields=" || candidates~items)
  field = candidates[1]
  if field~row \== 20 | field~column \== 7 then do
    return .TerminalResult~failure("MAIN_MENU_COMMAND_FIELD_POSITION", "expected 20,7 got " || field~row || "," || field~column)
  end
  return .TerminalResult~success(field)

::method findRowContainingCI class private
  use arg snapshot, needleArg
  needle = needleArg~string~upper
  do r = 1 to snapshot~rows
    if pos(needle, snapshot~rowText(r)~upper) > 0 then return r
  end
  return 0

::method findNewPasswordRow class private
  use arg snapshot, verifyRow
  do r = 1 to snapshot~rows
    text = snapshot~rowText(r)~upper
    if pos("NEW PASSWORD", text) > 0 & r \== verifyRow then return r
  end
  return 0

::method firstInputColumnOnRow class private
  use arg snapshot, rowArg
  best = 0
  do f over snapshot~fields
    if f~row \== rowArg then iterate
    if \f~inputCapable | f~protected then iterate
    if best = 0 | f~column < best then best = f~column
  end
  return best

::method passwordFieldMap class private
  use arg currentField, newField, verifyField
  a = .array~new
  a~append("current=" || currentField~row || "," || currentField~column || "," || currentField~length)
  a~append("new=" || newField~row || "," || newField~column || "," || newField~length)
  a~append("verify=" || verifyField~row || "," || verifyField~column || "," || verifyField~length)
  return a

/* Public structured mapping used by the trusted password-change consumer.
 * It deliberately returns field objects, never any field contents. */
::method findChangePasswordFields class
  use arg snapshot
  if snapshot == .nil then return .TerminalResult~failure("CHANGE_PASSWORD_NO_SNAPSHOT", "snapshot is required")
  if snapshot~terminalType \== "IBM5250" then return .TerminalResult~failure("CHANGE_PASSWORD_WRONG_TERMINAL", snapshot~terminalType)

  currentRow = self~findRowContainingCI(snapshot, "CURRENT PASSWORD")
  verifyRow = self~findRowContainingCI(snapshot, "NEW PASSWORD (TO VERIFY)")
  newRow = self~findNewPasswordRow(snapshot, verifyRow)
  if currentRow = 0 then return .TerminalResult~failure("CHANGE_PASSWORD_CURRENT_LABEL_NOT_FOUND", "Current password")
  if newRow = 0 then return .TerminalResult~failure("CHANGE_PASSWORD_NEW_LABEL_NOT_FOUND", "New password")
  if verifyRow = 0 then return .TerminalResult~failure("CHANGE_PASSWORD_VERIFY_LABEL_NOT_FOUND", "New password (to verify)")

  currentColumn = self~firstInputColumnOnRow(snapshot, currentRow)
  newColumn = self~firstInputColumnOnRow(snapshot, newRow)
  verifyColumn = self~firstInputColumnOnRow(snapshot, verifyRow)
  if currentColumn = 0 then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_MAPPING", "current password field missing")
  if newColumn = 0 then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_MAPPING", "new password field missing")
  if verifyColumn = 0 then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_MAPPING", "verification password field missing")

  currentField = snapshot~fieldAt(currentRow, currentColumn)
  newField = snapshot~fieldAt(newRow, newColumn)
  verifyField = snapshot~fieldAt(verifyRow, verifyColumn)
  if currentField == .nil then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_MAPPING", "current password field not found")
  if newField == .nil then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_MAPPING", "new password field not found")
  if verifyField == .nil then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_MAPPING", "verification password field not found")

  do f over .array~of(currentField, newField, verifyField)
    if \f~inputCapable then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_INVALID", f~fieldId)
    if f~protected then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_INVALID", f~fieldId)
    if \f~nonDisplay then return .TerminalResult~failure("CHANGE_PASSWORD_FIELD_VISIBILITY", f~fieldId)
  end

  mapped = .directory~new
  mapped["current"] = currentField
  mapped["new"] = newField
  mapped["verify"] = verifyField
  return .TerminalResult~success(mapped)

::method findCredentialFields class
  use arg snapshot
  users = .array~new
  passwords = .array~new
  do f over snapshot~fields
    if \f~inputCapable | f~protected then iterate
    if f~nonDisplay then passwords~append(f)
    else users~append(f)
  end
  if users~items \== 1 then return .TerminalResult~failure("LOGIN_USER_FIELD_AMBIGUOUS", "input/display fields=" || users~items)
  if passwords~items \== 1 then return .TerminalResult~failure("LOGIN_PASSWORD_FIELD_AMBIGUOUS", "input/nondisplay fields=" || passwords~items)
  pair = .directory~new
  pair["user"] = users[1]
  pair["password"] = passwords[1]
  return .TerminalResult~success(pair)

::class TN5250CredentialLogin public
::method stage class
  use arg runtime, broker, catalog, credentialReferenceArg, expectedStateIdArg = "IBM_I_SIGNON"
  snap = runtime~snapshot
  matched = catalog~match(snap)
  if matched~status \== .TerminalMatchStatus~MATCH then return .TerminalResult~failure("LOGIN_STATE_NOT_CONFIRMED", matched~status)
  if matched~matchedStateId \== expectedStateIdArg~string then return .TerminalResult~failure("LOGIN_WRONG_KNOWN_STATE", matched~matchedStateId)

  fields = .KnownState5250Factory~findCredentialFields(snap)
  if \fields~ok then return fields
  pair = fields~value

  acquired = broker~acquire(credentialReferenceArg)
  if \acquired~ok then return acquired
  lease = acquired~value

  staged = runtime~applyCredentialLease(snap~generation, pair["user"]~fieldId, pair["password"]~fieldId, lease)
  lease~retire
  if \staged~ok then return staged

  safeSnap = runtime~snapshot
  result = .TN5250CredentialStageResult~new(credentialReferenceArg, expectedStateIdArg, pair["user"]~fieldId, pair["password"]~fieldId, safeSnap)
  return .TerminalResult~success(result)

::requires "TN5250Automation.cls"
::requires "TerminalCredential.cls"
::requires "KnownStateJsonStore.cls"
