/* Memory and per-call cost over many SQLCommand calls. Claude (Opus 5.5). */
call rxfuncadd 'SQLLoadFuncs', 'rexxsql', 'SQLLoadFuncs'; call SQLLoadFuncs
call SQLConnect 'c1',,,':memory:'
call SQLCommand 'd', 'create table t (k varchar primary key, v text)'
call SQLCommand 'b', 'begin'
do i = 1 to 20000; call SQLCommand 'i', "insert into t values ('k"i"','" || copies('x', 200) || "')"; end
call SQLCommand 'c', 'commit'
do round = 1 to 6
  call time 'R'
  do i = 1 to 20000; call SQLCommand 'q', "select v from t where k='k" || random(1,20000) || "'"; end
  e = time('E')
  address system 'grep VmRSS /proc/'SysQueryProcess('PID')'/status' with output stem o.
  rss = o.1~word(2)
  say 'round' round ': 20000 keyed selects in' format(e,,2) 's =' format(e/20000*1000000,,0) 'us each; RSS' rss 'kB'
end
