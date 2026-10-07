/* numeric_torture.rex -- observe Rexx numeric semantics without normalising them */
numeric digits 50
numeric form scientific

say "rexx-numeric-digits:" digits()
say "rexx-numeric-form:" form()

big = 12345678901234567890123456789012345678901234567890
tenth = 0.1
precise = 1.234567890123456789012345678901234567890123456789
lexical = "00123.4500"
tiny = 1E-40
huge = 1E+100

say "rexx-big:" big
say "rexx-tenth:" tenth
say "rexx-precise:" precise
say "rexx-lexical:" lexical
say "rexx-tiny:" tiny
say "rexx-huge:" huge

/* Prove that lexical-looking numeric data is still a String value whose
   spelling can matter independently of numeric comparison. */
say "lexical-exact:" (lexical == "00123.4500")
say "lexical-numeric-equal:" (lexical = 123.45)

/* Arithmetic is deliberately performed under DIGITS 50. */
say "tenth-times-ten:" tenth * 10
say "big-plus-one:" big + 1

numeric fuzz 3
say "rexx-numeric-fuzz:" fuzz()
say "fuzz-comparison:" (1.0000000000000000000000000000000000000000000000000 =,
                        1.0000000000000000000000000000000000000000000000001)

say "REXX NUMERIC TORTURE PASS"
