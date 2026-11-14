#!/usr/bin/env rexx
/* python_gate.rex -- fail a package that carries or calls unjustified Python.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 * Usage:  rexx python_gate.rex <package-root> [--output report.json] [--quiet] [--advisory]
 * Progress goes to stderr through oorexx_logging; the JSON report goes to
 * stdout (or --output).  Exit 0 = PASS, 1 = FAIL, 2 = usage error.
 * --advisory: report as normal but always exit 0 (for a staged roll-out).
 */
parse arg argline
root = ""
output = ""
quiet = .false
advisory = .false
do while argline \= ""
  parse var argline word argline
  select
    when word == "--output" then parse var argline output argline
    when word == "--quiet" then quiet = .true
    when word == "--advisory" then advisory = .true
    when root == "" then root = word
    otherwise do
      .error~lineout("python_gate: unexpected argument" word)
      exit 2
    end
  end
end
if root == "" then do
  .error~lineout("usage: rexx python_gate.rex <package-root> [--output report.json] [--quiet] [--advisory]")
  exit 2
end
root = qualify(root)

gate = .PythonGate~new(root)
progress = .ToolProgress~new("python-gate", gate, "RUN")
if quiet then progress~quiet
gate~useLogger(progress~logger)
report = gate~run
if advisory then report["mode"] = "advisory"
else report["mode"] = "enforce"

text = .json~toJSON(report, .true)
if output \= "" then .stream~new(output)~~open("write replace")~~lineout(text)~~close
else say text
if report["status"] == "PASS" then exit 0
if advisory then do
  .error~lineout("python_gate: ADVISORY - status" report["status"] "not enforced")
  exit 0
end
exit 1

::requires "../src/PythonGate.cls"
::requires "../../oorexx_logging_stream_target_v0.1/src/LogStreamTarget.cls"
::requires "json.cls"
