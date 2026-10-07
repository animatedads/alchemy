/* Structural target for dev3: recursive compound/list construction. */
r = .AlchemyPrologRuntime~new
e = r~engine
x = r~variable("X")
pair = r~compound("pair", .array~of(r~atom("left"), x))
xs = r~list(.array~of(r~atom("a"), r~atom("b"), pair))
/* A user predicate can now receive xs without stringifying its structure. */
say xs~prologSpec[1] pair~prologSpec[1]
e~close
