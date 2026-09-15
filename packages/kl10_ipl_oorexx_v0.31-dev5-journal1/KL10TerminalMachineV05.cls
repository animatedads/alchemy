/* Optional bridge from KL10Console into ooRexx Terminal Machine v0.5.
 *
 * This file deliberately requires TerminalCore.cls only when the bridge is
 * used. The KL10 core remains independently usable.
 *
 * No CPU, DTE, memory, or bus getter is exposed here. Actions continue through
 * KL10ConsoleKeyboard and therefore through DTE20 RX/service.
 */

::class KL10TerminalModelV05 public

::method init
  expose console
  use strict arg consoleArg
  console=consoleArg

::method snapshot
  expose console
  ks=console~snapshot

  rows=.array~new
  do row=1 to ks~rows
    rows~append(ks~rowText(row))
  end

  caps=.TerminalCapabilities~new
  caps~add("CHARACTER_STREAM")
  caps~add("CHARACTER_INPUT")
  caps~add("CONTROL_KEYS")
  caps~add("SNAPSHOT")
  caps~add("STALE_ACTION_TOKEN")
  caps~add("KL10_DTE20")

  md=.directory~new
  md["stateToken"]=ks~stateToken
  md["guestWaitingForInput"]=ks~guestWaitingForInput
  md["inputReady"]=ks~inputReady
  md["queuedInputBytes"]=ks~queuedInputBytes
  md["instructionCount"]=ks~instructionCount
  md["pcOctal"]=.LROct~fromDecimal(ks~pc)~right
  md["monitorMode"]=ks~monitorMode
  md["outputBytes"]=ks~outputBytes
  md["bellCount"]=ks~bellCount

  content=.TerminalUtil~stableDigest(ks~visibleText)
  layout=.TerminalUtil~stableDigest("KL10-DTE20|ASCII-7|STREAM")

  return .TerminalSnapshot~new(ks~generation, "KL10-DTE20", -
      ks~rows, ks~columns, ks~cursorRow, ks~cursorColumn, -
      ks~keyboardState, ks~sessionState, rows, .nil, caps, md, content, layout)

::method type
  expose console
  use strict arg text, expectedToken
  r=console~keyboard~type(text,expectedToken)
  return self~terminalResult(r)

::method typeLine
  expose console
  use strict arg text, expectedToken
  r=console~keyboard~typeLine(text,expectedToken)
  return self~terminalResult(r)

::method press
  expose console
  use strict arg key, expectedToken
  r=console~keyboard~press(key,expectedToken)
  return self~terminalResult(r)

::method control
  expose console
  use strict arg key, expectedToken
  r=console~keyboard~control(key,expectedToken)
  return self~terminalResult(r)

::method pump
  expose console
  use arg maxSteps=200, stopMode="WAIT"
  r=console~pump(maxSteps,stopMode)
  if r~ok then return .TerminalResult~success(self~snapshot)
  return .TerminalResult~failure(r~reason,r~conditionMessage)

::method terminalResult private
  use strict arg r
  if r~ok then return .TerminalResult~success(self~snapshot)
  code=r~code
  if code="STALE_STATE" then code="STALE_ACTION_TOKEN"
  return .TerminalResult~failure(code,r~detail)

::requires "KL10Console.cls"
::requires "TerminalCore.cls"
