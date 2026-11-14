#!/usr/bin/env rexx
/* verify_release_archives.rex -- verify the historical Windows RC archives.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14 (ooRexx
 * port of verify_release_archives.py; also checks the SHA-256 the sphere
 * records for each archive, which the Python tool did not).
 *
 *   rexx tools/verify_release_archives.rex --directory DIR [--output report.json]
 *
 * Progress goes to stderr through oorexx_logging; the JSON report to stdout
 * or --output.  Exit 0 only if every version verifies.  Archive integrity
 * only; never compiler or semantic compatibility.
 */
parse arg argline
directory = ""
output = ""
do while argline \= ""
  parse var argline word argline
  select
    when word == "--directory" then parse var argline directory argline
    when word == "--output" then parse var argline output argline
    otherwise do
      .error~lineout("verify_release_archives: unexpected argument" word)
      exit 2
    end
  end
end
if directory == "" then do
  .error~lineout("usage: rexx verify_release_archives.rex --directory DIR [--output FILE]")
  exit 2
end

ev = .RcArchiveEvidence~new
ev~useLogger(.ToolProgress~new("rc-archive-evidence", ev, "RUN")~logger)
report = ev~run(directory)
text = .json~toJSON(report, .true)
if output \= "" then .stream~new(output)~~open("write replace")~~lineout(text)~~close
else say text
if report["all_verified"]~value then exit 0
exit 1

::requires "../src/RcArchiveEvidence.cls"
::requires "../../oorexx_logging_stream_target_v0.1/src/LogStreamTarget.cls"
::requires "json.cls"
