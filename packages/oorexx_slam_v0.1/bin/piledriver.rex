/* piledriver.rex - Piledriver v0.1 command line: logs, tables and sheets, with no model.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-30.
 *
 *   rexx piledriver.rex sniff FILE...            what kind of file each one is, and why
 *   rexx piledriver.rex read FILE [N]            read FILE by its kind (a log, or a table) and report
 *   rexx piledriver.rex errors FILE              every error record of a log, one per line
 *   rexx piledriver.rex learn CATALOG FILE...    read each FILE and add its templates to CATALOG
 *   rexx piledriver.rex compare CATALOG FILE     read FILE against CATALOG: what is new, what went away
 *
 * REXX_PATH must reach this package's src directory (and csvStream.cls, which ships with ooRexx).
 */
signal on syntax name onSyntax
parse arg cmd rest
cmd = cmd~lower
select
  when cmd == 'sniff' then do
    do path over rest~subWords
      r = .PiledriverSource~sniff(path)
      say r['KIND']~left(10) path
      do e over r['EVIDENCE']
        say '           ' e
      end
    end
  end
  when cmd == 'read' then do
    parse var rest path most .
    if most == '' then most = 12
    kind = .PiledriverSource~sniff(path)['KIND']
    if wordpos(kind, 'CSV TSV DELIMITED') > 0 then report = .PiledriverTable~new~readFile(path)~report(most)
    else if kind == 'LOG' then do
      log = .PiledriverLog~new
      log~readFile(path)
      report = log~report(most)
    end
    else report = .array~of('piledriver:' path 'is' kind || ': not read here (XLSX/ODS: SpreadsheetReader; JSON: json.cls)')
    do line over report
      say line
    end
  end
  when cmd == 'errors' then do
    log = .PiledriverLog~new
    log~readFile(rest~strip)
    do r over log~errors('ERROR WARN')
      say r~describe
    end
  end
  when cmd == 'learn' then do
    parse var rest catalog files
    do path over files~subWords
      log = .PiledriverLog~new
      log~loadCatalog(catalog)
      log~readFile(path)
      n = log~saveCatalog(catalog)
      say 'learned' path || ':' log~counts~items 'templates; catalog now' n 'lines'
    end
  end
  when cmd == 'compare' then do
    parse var rest catalog path .
    log = .PiledriverLog~new
    log~loadCatalog(catalog)
    log~readFile(path)
    say 'new in' path || ':'
    do a over log~arrived
      say '  ' || a[2]~right(6) a[3]~left(8) a[1]
    end
    say 'in the catalog, not in' path || ':'
    do g over log~gone
      say '  ' || g[2]~right(6) g[3]~left(8) g[1]
    end
    say 'records with codes not seen before:'
    do r over log~records
      if r~status == 'NEW_CODES' then say '  ' r~describe
    end
  end
  otherwise do
    say 'usage: rexx piledriver.rex sniff|read|errors|learn|compare ...'
    exit 2
  end
end
exit 0

onSyntax:
  say 'piledriver: error' condition('C') 'rc' rc 'line' sigl || ':' condition('D')
  exit 1

::requires 'PiledriverSource.cls'
::requires 'PiledriverLog.cls'
::requires 'PiledriverTable.cls'
