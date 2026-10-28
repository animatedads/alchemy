/* ooRexx's qtime at each time in the cases file. Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28. */
parse arg file
do while lines(file) > 0
  parse value linein(file) with hh mm ss
  say hh':'mm':'ss englishAt(hh + 0, mm + 0, ss + 0)
end
::requires 'qtime_classes.rex'
