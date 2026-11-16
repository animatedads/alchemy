#!/usr/bin/env rexx
/* corpus_inventory.rex -- inventory original ooRexx Windows RC files.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14 (ooRexx
 * port of corpus_inventory.py; same arguments, report and exit status).
 *
 *   rexx tools/corpus_inventory.rex --checkout /path/to/ooRexx [--manifest file] [--output report.json]
 *
 * Progress goes to stderr through oorexx_logging; the JSON report to stdout
 * or --output.  Exit 0 only if every manifest file and its quoted includes
 * are present.
 */
parse arg argline
here = filespec("location", .context~package~name)
checkout = ""
manifest = here"../corpus/official_oodialog.txt"
output = ""
do while argline \= ""
  parse var argline word argline
  select
    when word == "--checkout" then parse var argline checkout argline
    when word == "--manifest" then parse var argline manifest argline
    when word == "--output" then parse var argline output argline
    otherwise do
      .error~lineout("corpus_inventory: unexpected argument" word)
      exit 2
    end
  end
end
if checkout == "" then do
  .error~lineout("usage: rexx corpus_inventory.rex --checkout DIR [--manifest FILE] [--output FILE]")
  exit 2
end

inv = .RcCorpusInventory~new
inv~useLogger(.ToolProgress~new("rc-corpus-inventory", inv, "RUN")~logger)
report = inv~run(checkout, manifest)
text = .json~toJSON(report, .true)
if output \= "" then .stream~new(output)~~open("write replace")~~lineout(text)~~close
else say text
if inv~passed(report) then exit 0
exit 1

::requires "../src/RcCorpusInventory.cls"
::requires "../../oorexx_logging_stream_target_v0.1/src/LogStreamTarget.cls"
::requires "json.cls"
