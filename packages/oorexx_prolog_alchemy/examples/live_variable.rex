/* Illustrative once native library is built and member/2 is available. */
runtime = .AlchemyPrologRuntime~new
engine = runtime~engine
x = runtime~variable("X")
/* list construction is the next term-shape increment; this example demonstrates
 * the live-variable contract with a user predicate choose/2 whose second arg is X. */
q = engine~query("user", "between", .array~of(runtime~integer(1), runtime~integer(3), x))
do while q~nextSolution
  say "X=" x~text " bound=" x~bound
end
engine~close
::requires '../src/AlchemyProlog.cls'
