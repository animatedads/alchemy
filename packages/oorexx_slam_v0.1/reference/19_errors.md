# error numbers

this file is from the part of the rexx language rules with the list of error numbers.
title: the name of an error with its number; it is in the first line of the code for the error
interpret: an instruction that runs a string as code
select: an instruction that has one or more when clauses
control: the control variable of a loop is the variable that the loop changes each time it runs
address: an instruction that names the environment for commands
parenthesis: one of the two parentheses marks
for each error, the code has its title, then the second error numbers, each with its message.
after the code are facts about the error.

```
Error 3 - Failure during initialization.
001 Failure during initialization: File "filename" is unreadable.
900 message.
901 Failure during initialization: Program "program" was not found.
902 Error writing output file "file".
903 Program "program_name" cannot be run by this version of the REXX interpreter.
905 Encoded compiled program "program_name" cannot be decoded.
```
this error is raised when the computer can not read the rexx program from the disk.

```
Error 4 - Program interrupted.
001 Program interrupted with condition condition.
900 message.
```
this error is raised when the computer stops the program, for an error or when the user has a need to stop it.

```
Error 5 - System resources exhausted.
900 message.
```
this error is raised when the language can not get the memory or other things it needs to run a program, as memory for its variables.

```
Error 6 - Unmatched "/*" or quote.
001 Unmatched comment delimiter ("/*") on line line_number.
002 Unmatched single quote (').
003 Unmatched double quote (").
900 message.
```
this error is raised when a comment or a literal starts and has no end.
it is raised when the program, or the string of an interpret instruction, ends before the end of the comment or the end quote mark.
it is also raised when a line ends in a literal.

```
Error 7 - WHEN or OTHERWISE expected.
001 SELECT on line line_number requires WHEN.
002 SELECT on line line_number requires WHEN, OTHERWISE, or END.
003 All WHEN expressions of SELECT are false; OTHERWISE expected.
```
this error is raised when a select instruction does not have the when clause it needs.
it is raised when an other instruction is where a when clause has to be.
it is raised when there is no when clause before the other clause in the title.
it is raised when all when expressions are false and there is no clause with the other keyword in the title.

```
Error 8 - Unexpected THEN or ELSE.
001 THEN has no corresponding IF or WHEN clause.
002 ELSE has no corresponding THEN clause.
```
this error is raised when a then clause or an else clause has no if clause or when clause for it.
it can come when an end is not there in the then part of an if instruction.

```
Error 9 - Unexpected WHEN or OTHERWISE.
001 WHEN has no corresponding SELECT.
002 OTHERWISE has no corresponding SELECT.
```
this error is raised when a when clause or the other clause in the title is outside of a select instruction.
it can come when a group has no end, or when a signal goes to that clause after the instruction is at its end.

```
Error 10 - Unexpected or unmatched END.
001 END has no corresponding DO, LOOP, or SELECT.
002 Symbol following END ("symbol") must match block specification name ("name") on line line_number or be omitted.
003 END corresponding to block on line symbol must not have a symbol following it because there is no LABEL or control variable
004 Symbol following END ("symbol") must match LABEL of SELECT specification ("name") on line line_number or be omitted.
005 END must not immediately follow THEN.
006 END must not immediately follow ELSE.
007 END corresponding to SELECT on line symbol must not have a symbol following it because there is no LABEL
```
this error is raised when the program has more end clauses than do, loop, or select instructions, or when an end is not for the instruction it has to end.
it is also raised when an end is next after then or else.
it is also raised when the name after the end is not the name after the do or loop.

```
Error 11 - Control stack full.
001 Insufficient control stack space; cannot continue execution.
900 message.
```
this error is raised when there is no more memory for the list of the calls that run.
it can come when an interpret instruction runs the same interpret instruction in a loop, or when a routine calls the same routine and does not end.

```
Error 13 - Invalid character in program.
001 Incorrect character in program "character" ('hex_character'X).
900 message.
```
this error is raised when a character outside a literal is not a blank, a letter, a digit, or a special character of the language.

```
Error 14 - Incomplete DO/LOOP/SELECT/IF.
001 DO instruction on line line_number requires matching END.
002 SELECT instruction on line line_number requires matching END.
003 THEN on line line_number must be followed by an instruction.
004 ELSE on line line_number must be followed by an instruction.
005 DO or LOOP instruction on line line_number requires matching END.
901 OTHERWISE on line line_number requires matching END.
```
this error is raised when the program, or the string of an interpret instruction, ends and a group is not at its end.
it is raised when a do, loop, or select instruction has no end.
it is raised when an if clause has no then clause after it.

```
Error 15 - Invalid hexadecimal or binary string.
001 Incorrect location of whitespace character in position position in hexadecimal string.
002 Incorrect location of whitespace character in position position in binary string.
003 Only 0-9, a-f, A-F, and whitespace characters are valid in a hexadecimal string; found "character".
004 Only 0, 1, and whitespace characters are valid in a binary string; found "character".
005 Hexadecimal strings must be grouped in units that are multiples of two characters.
006 Binary strings must be grouped in units that are multiples of four characters.
```
this error is raised when a hexadecimal string or a binary string in the code is not right.
a hexadecimal string can have only the digits and the letters of hexadecimal, with blanks only between bytes, and no blank at the start or end.
a binary string can have only zero and one, with blanks only between one group of four digits and the next group.

```
Error 16 - Label not found.
001 Label "label_name" not found.
```
this error is raised when a signal instruction runs, or a signal on trap runs for an event, and the language can not find the label.

```
Error 17 - Unexpected PROCEDURE.
001 PROCEDURE is valid only when it is the first instruction executed after an internal CALL or function invocation.
901 INTERPRET data must not contain PROCEDURE.
```
this error is raised when a procedure instruction is at a place where it can not be.
it can be only the first instruction that runs after an internal call or function call.
the string of an interpret instruction can not have a procedure instruction.

```
Error 18 - THEN expected.
001 IF instruction on line line_number requires matching THEN clause.
002 WHEN instruction on line line_number requires matching THEN clause.
```
this error is raised when an if clause or a when clause has no then clause after it.
the language finds an other clause before it finds a then clause.

```
Error 19 - String or symbol expected.
001 String or symbol expected after ADDRESS keyword.
002 String or symbol expected after CALL keyword.
003 String or symbol expected after NAME keyword.
004 String or symbol expected after SIGNAL keyword.
006 String or symbol expected after TRACE keyword.
007 String or symbol expected after PARSE keyword.
900 message.
901 String or symbol expected after ::CLASS keyword.
902 String or symbol expected after ::METHOD keyword.
903 String or symbol expected after ::ROUTINE keyword.
904 String or symbol expected after ::REQUIRES keyword.
905 String expected after EXTERNAL keyword.
906 String or symbol expected after METACLASS keyword.
907 String or symbol expected after SUBCLASS keyword.
908 String or symbol expected after INHERIT keyword.
909 String or symbol expected after tilde (~).
911 String or symbol expected after superclass colon (:).
912 String or symbol expected after STREAM keyword.
913 String or symbol expected after MIXINCLASS keyword.
914 String or symbol expected as ::ATTRIBUTE directive name.
915 String or symbol expected as ::CONSTANT directive name.
916 String or symbol expected as ::CONSTANT value.
917 String or symbol expected as DIGITS value.
918 String or symbol expected as FUZZ value.
919 String or symbol expected as TRACE value.
920 String or symbol expected as ::RESOURCE directive name.
921 String or symbol expected after ::RESOURCE END keyword.
922 String or symbol expected after keyword keyword.
923 Symbol or string expected as ::ANNOTATE attribute value; found "name".
924 Symbol or string expected as ::ANNOTATE attribute value.
925 Symbol or string expected after directive keyword keyword.
```
this error is raised when the language needs a symbol or a string in a keyword instruction, a directive, or an expression, and there is no symbol or string.

```
Error 20 - Symbol expected.
900 message.
901 Symbol expected after DROP keyword.
902 Symbol expected after EXPOSE keyword.
903 Symbol expected after PARSE keyword.
904 Symbol expected after PARSE VAR.
905 NUMERIC must be followed by one of the keywords DIGITS, FORM, or FUZZ; found "symbol".
906 Symbol expected after "(" of a variable reference.
907 Symbol expected after LEAVE keyword.
908 Symbol expected after ITERATE keyword.
909 Symbol expected after END keyword.
911 Symbol expected after ON keyword.
912 Symbol expected after OFF keyword.
913 Symbol expected after USE ARG.
914 Symbol expected after RAISE keyword.
915 Symbol expected after USER keyword.
916 Symbol expected after ::.
917 Symbol expected after superclass colon (:).
918 Symbol expected after LABEL keyword.
919 Symbol expected as ::ANNOTATE attribute name; found "name".
920 Symbol expected after NAMESPACE keyword.
921 Symbol expected as a class name of qualified class name.
922 Symbol expected as a routine name of qualified CALL instruction.
923 Symbol expected as a name of namespace-qualified symbol.
924 Symbol expected for the ::ANNOTATE type.
925 Symbol expected after the FORM keyword.
926 Symbol expected after the DELEGATE keyword.
927 Symbol expected after USE LOCAL.
928 Symbol expected as an indirect variable name; found "token".
929 Symbol expected after keyword keyword.
930 Simple variable or stem symbol expected after > or < prefix operator; found token.
931 Simple variable or stem symbol expected after > or < USE ARG reference operator; found token.
932 Stem symbol expected after STEM keyword.
933 Symbol expected after WITH keyword.
934 Symbol expected after COUNTER keyword.
935 Symbol expected after the NUMERIC subdirective keyword.
```
this error is raised when the language needs a symbol in a keyword instruction, a directive, or an expression.
there is no symbol where it needs one, or the language finds an other token.

```
Error 21 - Invalid data on end of clause.
900 message.
901 Data must not follow the NOP keyword; found "data".
902 Data must not follow the SELECT keyword; found "data".
903 Data must not follow the NAME trap name; found "data".
904 Data must not follow the condition name; found "data".
905 Data must not follow the SIGNAL label name; found "data".
906 Data must not follow the TRACE setting; found "data".
907 Data must not follow the LEAVE name; found "data".
908 Data must not follow the ITERATE name; found "data".
909 Data must not follow the END name; found "data".
911 Data must not follow the NUMERIC FORM specification; found "data".
912 Data must not follow the GUARD OFF specification; found "data".
913 Data must not follow the ::CONSTANT value; found "data".
914 Data must not follow the ::RESOURCE directive; found "data".
```
this error is raised when a keyword instruction or a directive has a token after it that is not a comment.

```
Error 22 - Invalid character string.
001 Incorrect character string "character_string" ('hex_string'X).
900 message.
901 Incorrect double-byte character.
```
this error is raised when a literal has characters that the language can not use.

```
Error 23 - Invalid data string.
001 Incorrect data string "string" ('hex_string'X).
900 message.
```
this error is raised when a data string, the result of an expression, has characters that the language can not use.

```
Error 24 - Invalid TRACE request.
001 TRACE request letter must be one of "ACEFILNOR"; found "value".
901 Numeric TRACE requests are valid only from interactive debugging.
```
this error is raised when the option of a trace instruction, or the argument of the trace builtin function, does not start with one of the letters in the code.
it is also raised when you give a number that is not a whole number while you debug and the program is interactive.

```
Error 25 - Invalid subkeyword found.
NUMERIC DIGITS | FORM | FUZZ
```
this error is raised when the language finds a token it does not want in a keyword instruction or a directive, where it needs a keyword.
for one, the token after the first keyword in the second line of the code must be one of the other three keywords in that line.

```
Error 26 - Invalid whole number.
002 Value of repetition count expression in DO or LOOP instruction must be zero or a positive whole number; found "value".
003 Value of FOR expression in DO or LOOP instruction must be zero or a positive whole number; found "value".
004 Positional pattern of PARSE template must be a whole number; found "value".
005 DIGITS value must be a positive whole number; found "value".
006 FUZZ value must be zero or a positive whole number; found "value".
007 Number used in TRACE setting must be a whole number; found "value".
008 Operand to the right of the power operator (**) must be a whole number; found "value".
011 Result of % operation did not result in a whole number.
012 Result of // operation did not result in a whole number.
900 message.
901 Result of a method call did not result in a whole number; found "value".
902 Result of a COMPARETO method call did not result in a whole number; found "value".
903 Result of a COMPARE method call did not result in a whole number; found "value".
904 Stem "stem" element 0 is not a whole number; found "count".
```
this error is raised when an expression that must give a whole number does not give one.
it is also raised when the value is more than the maximum: 999999999 on a computer of 32 bits, and 999999999999999999 on a computer of 64 bits.
it is raised for a positional pattern of a parse template, the operand at the right of the power operator, values of do and loop instructions, the precision values, and a number in a trace instruction.
it is also raised for a value the language can not use, as a negative count of times for a loop.
it is also raised when an integer divide or a remainder does not give a whole number.

```
Error 27 - Invalid DO or LOOP syntax.
001 Only one WHILE or UNTIL condition can be used on the same loop.
901 Incorrect data following FOREVER keyword on the loop; found "data".
902 DO or LOOP keyword keyword can be specified only once.
903 No INDEX or ITEM control variable specified on a WITH loop.
904 OVER keyword expected for a WITH loop.
905 COUNTER keyword not allowed on a simple DO instruction.
```
this error is raised when a do or loop instruction has an error in its rules.
as a rule it comes when a keyword of the loop is in it two times, when a loop has both while and until, or when a loop has a keyword that needs a control variable and has no control variable.

```
Error 28 - Invalid LEAVE or ITERATE.
001 LEAVE is valid only within a repetitive loop or labeled block instruction.
002 ITERATE is valid only within a repetitive loop.
003 Symbol following LEAVE ("symbol") must either match the label of a current loop or block instruction.
004 Symbol following ITERATE ("symbol") must either match the label of a current loop or be omitted.
005 Symbol following ITERATE ("symbol") does not match a repetitive block instruction.
```
this error is raised when a leave instruction or the other instruction in the title is at a place where it can not be.
it comes when no loop is running, or when the name in the instruction is not the name of the control variable of a loop that is running.

```
Error 29 - Environment name too long.
001 Environment name exceeds limit characters; found "environment_name".
```
this error is raised when the name of the environment in an address instruction is more characters than the computer can use.

```
Error 30 - Name or symbol too long.
001 Name or symbol exceeds 250 characters: "name".
900 message.
```
this error is raised when the name of a variable, the name of a label, or a symbol has more than 250 characters.

```
Error 31 - Name starts with number or ".".
001 A value cannot be assigned to a number; found "number".
002 Variable symbol must not start with a number; found "symbol".
003 Variable symbol must not start with a "."; found "symbol".
900 message.
```
this error is raised when the name of a variable starts with a digit or a point.

```
Error 33 - Invalid expression result.
001 Value of NUMERIC DIGITS ("value") must exceed value of NUMERIC FUZZ ("value").
002 Value of NUMERIC DIGITS ("value") must not exceed value.
900 message.
901 Incorrect expression result following VALUE keyword of ADDRESS instruction.
902 Incorrect expression result following VALUE keyword of SIGNAL instruction.
903 Incorrect expression result following VALUE keyword of TRACE instruction.
904 Incorrect expression result following SYNTAX keyword of RAISE instruction.
```
this error is raised when the result of an expression is not a value that the language can use at that place.

```
Error 34 - Logical value not 0 or 1.
001 Value of expression following IF keyword must be exactly "0" or "1"; found "value".
002 Value of expression following WHEN keyword must be exactly "0" or "1"; found "value".
003 Value of expression following WHILE keyword must be exactly "0" or "1"; found "value".
004 Value of expression following UNTIL keyword must be exactly "0" or "1"; found "value".
005 Value of expression to the left of the logical operator "operator" must be exactly "0" or "1"; found "value".
006 Value of logical list expression element must be exactly "0" or "1"; found "value".
900 message.
901 Logical value must be exactly "0" or "1"; found "value".
902 Value of expression following GUARD keyword must be exactly "0" or "1"; found "value".
903 Authorization return value must be exactly "0" or "1"; found "value".
904 Property logical value must be exactly "0", "1", "true", or "false"; found "value".
905 SELECT CASE comparison result must be exactly "0" or "1"; found "value".
906 Supplier AVAILABLE method did not return exactly "0" or "1"; found "value".
```
this error is raised when an expression, as in an if, when, while, or until part of an instruction, does not give 0 or 1.

```
Error 35 - Invalid expression.
001 Incorrect expression detected at "token".
900 message.
901 Prefix operator "operator" is not followed by an expression term.
902 Missing conditional expression following IF keyword.
903 Missing conditional expression following WHEN keyword.
904 Missing initial expression for DO or LOOP control variable.
905 Missing expression following BY keyword.
906 Missing expression following TO keyword.
907 Missing expression following FOR keyword.
908 Missing expression following WHILE keyword.
909 Missing expression following UNTIL keyword.
911 Missing expression following OVER keyword.
912 Missing expression following INTERPRET keyword.
913 Missing expression following OPTIONS keyword.
914 Missing expression following VALUE keyword of an ADDRESS instruction.
915 Missing expression following VALUE keyword of a SIGNAL instruction.
916 Missing expression following VALUE keyword of a TRACE instruction.
917 Missing expression following VALUE keyword of a NUMERIC FORM instruction.
918 Missing expression following assignment instruction.
919 Operator "operator" is not followed by an expression term.
921 Missing expression following GUARD keyword.
922 Missing expression following DESCRIPTION keyword of a RAISE instruction.
923 Missing expression following ADDITIONAL keyword of a RAISE instruction.
924 Missing "(" on expression list of the ARRAY keyword.
925 Missing expression following TO keyword of a FORWARD instruction.
926 Missing expression following ARGUMENTS keyword of a FORWARD instruction.
927 Missing expression following MESSAGE keyword of a FORWARD instruction.
928 Missing expression following CLASS keyword of a FORWARD instruction.
929 Missing expression in logical expression list.
930 Invalid or missing expression following "=" token of a USE ARG instruction.
931 Missing expression following "(" of parse template.
932 Missing expression for calculated CALL name.
933 Missing expression following CASE keyword of a SELECT instruction.
934 Missing expression in WHEN case expression list.
935 Missing expression following keyword keyword of a instruction instruction.
936 Missing expression on ::CONSTANT directive.
```
this error is raised when an expression has an error in its rules.
it can come when there is no expression where the language needs one.
it can come when an expression ends with an operator.
it can come when an expression has two operators next to each other with no token between them.
it can come when there is no right parenthesis where the language needs one.
it can come when you use special characters, as operators, in an expression that has to be a string, and they are not between quote marks.

```
Error 36 - Unmatched "(" or "[" in expression.
900 message.
901 Left parenthesis "(" in position position on line line_number requires a corresponding right parenthesis ")".
902 Square bracket "[" in position position on line line_number requires a corresponding right square bracket "]".
```
this error is raised when an expression has more left parentheses than right parentheses, or more left square marks than right square marks.
to put one parenthesis in a command, put it between quote marks.

```
Error 37 - Unexpected ",", ")", or "]".
001 Unexpected ",".
002 Unmatched ")" in expression.
900 message.
901 Unexpected "]".
```
this error is raised when a comma is outside a function call, or when an expression has too many right parentheses or right square marks.
if a comma is a part of a string, put it between quote marks.
the code:
```rexx
Say Enter A, B, or C
```
the result:
```
ENTER A
B
OR C
```
the reference says:
```
error
```

the code:
```rexx
Say 'Enter A, B, or C'
```
the result:
```
Enter A, B, or C
```
the reference says:
```
right
```

```
Error 38 - Invalid template or pattern.
001 Incorrect PARSE template detected at "column_position".
002 Incorrect PARSE position detected at "column_position".
003 PARSE VALUE instruction requires WITH keyword.
900 message.
901 Missing PARSE relative position.
```
this error is raised when a parse template has a character it can not have.
it is also raised when a variable pattern has no symbol after the left parenthesis.
it is also raised when a parse instruction with the value keyword has no with keyword.

```
Error 39 - Evaluation stack overflow.
```
this error is raised when an expression has too many parts for the language to get its value.

```
Error 40 - Incorrect call to routine.
001 External routine "routine" failed.
003 Not enough arguments in invocation of routine; minimum expected is number.
004 Too many arguments in invocation of routine; maximum expected is number.
005 Missing argument in invocation of routine; argument argument_number is required.
011 function_name argument argument_number must be a number; found "value".
012 function_name argument argument_number must be a whole number; found "value".
013 function_name argument argument_number must be zero or positive; found "value".
014 function_name argument argument_number must be positive; found "value".
019 function_name argument 2, "value", is not in the format described by argument 3, "value".
021 function_name argument argument_number must not be a null string.
022 function_name argument argument_number must be a single character or null; found "value".
023 function_name argument argument_number must be a single character; found "value".
024 function_name argument argument_number must be a binary string; found "value".
025 function_name argument argument_number must be a hexadecimal string; found "value".
026 function_name argument argument_number must be a valid symbol; found "value".
027 function_name argument 1 must be a valid stream name; found "value".
028 function_name argument argument_number must be a character class name or a single character; found "value".
029 function_name conversion to format "value" is not allowed.
032 RANDOM difference between argument 1 ("value") and argument 2 ("value") must not exceed 999,999,999.
033 RANDOM argument 1 ("argument") must be less than or equal to argument 2 ("argument").
034 SOURCELINE argument 1 ("argument") must be less than or equal to the number of lines in the program (argument).
035 X2D argument 1 cannot be expressed as a whole number; found "value".
043 function_name argument number must be a single non-alphanumeric character or the null string; found "value".
044 function_name argument number, "value", is a format incompatible with the separator specified in argument number.
900 message.
901 Result returned by routine is longer than length: "value".
902 function_name argument argument_number must not exceed the whole number limit.
903 function_name argument argument_number must be in the range 0-99; found "value".
904 function_name argument argument_number must be one of values; found "value".
905 TRACE setting letter must be one of "ACEFILNOR"; found "value".
912 function_name argument argument_number must be a single-dimensional array; found "value".
913 function_name argument argument_number must have a string value; found "value".
914 Unknown VALUE function variable environment selector; found "value".
915 function_name cannot be used with QUEUE:.
916 Cannot read from a write-only property.
917 Cannot write to a read-only property or typelib element.
918 Invalid native function signature specification.
919 Argument argument must have a stem object or stem name value; found "value".
920 function_name argument name must be one of option; found "value".
921 Argument first option ("first value") must be greater than argument second option ("second value").
922 Stem argument does not have a valid count for element 0.
923 The operation is outside the size of the stem array ("value").
924 Stem element at position "position" is not set.
925 Argument argument must be an array object, a stem object, or a stem name value; found "value".
```
this error is raised when a call to a routine is not right.
it can come when you give the routine arguments that are not right, or too many arguments.
it can come when an external routine can not run with the language.
a symbol or a string next before a left parenthesis is a function call.

```
Error 41 - Bad arithmetic conversion.
001 Nonnumeric value ("value") used in arithmetic operation.
003 Nonnumeric value ("value") used with prefix operator.
004 Value of TO expression of DO or LOOP instruction must be numeric; found "value".
005 Value of BY expression of DO or LOOP instruction must be numeric; found "value".
006 Value of control variable expression of DO or LOOP instruction must be numeric; found "value".
007 Exponent exceeds number digits; found "value".
900 message.
901 Value of RAISE instruction SYNTAX expression must be numeric; found "value".
```
this error is raised when a part of a maths expression is not a number, or has an exponent that is more than the language can use.

```
Error 42 - Arithmetic overflow/underflow.
001 Arithmetic overflow detected at: "value operator value".
002 Arithmetic underflow detected at: "value operator value".
003 Arithmetic overflow; divisor must not be zero.
900 message.
901 Arithmetic overflow; exponent ("exponent") exceeds number digits.
902 Arithmetic underflow; exponent ("exponent") exceeds number digits.
903 Arithmetic underflow; zero raised to a negative power.
```
this error is raised when the result of maths needs an exponent with more than nine digits.

```
Error 43 - Routine not found.
001 Could not find routine "routine".
900 message.
901 Could not find file "file" for ::REQUIRES.
902 Routine "routineName" not found in namespace "namespace".
```
this error is raised when an expression calls a function, or a call instruction calls a subroutine, and the language can not find it.
it is not in the program, it is not a builtin function, and the language can not find it outside the program.
it can come when the name is not right, or when a symbol or string is next to a left parenthesis with no blank or operator between them.
the code:
```rexx
3(4+5)
```
the result:
```
43.1
```
the reference says:
```
error
```

the code:
```rexx
3*(4+5)
```
the result:
```
```
the reference says:
```
right
```

```
Error 44 - Function or message did not return data.
```
this error is raised when the language calls an external routine in an expression, and the routine ends with no error, but gives back no data for the expression.

```
Error 45 - No data specified on function RETURN.
001 Data expected on RETURN instruction because routine "routine" was called as a function.
```
this error is raised when a program calls a rexx program as a function, and the rexx program returns and gives back no data.

```
Error 46 - Invalid variable reference.
ARG  DROP  EXPOSE  PARSE  PULL  PROCEDURE
001 Extra token ("token") found in variable reference list; ")" expected.
900 message.
901 Missing ")" in variable reference.
902 Extra token ("token") found in USE ARG variable reference; "," or end of instruction expected.
```
this error is raised when a variable between parentheses in one of the instructions in the second line of the code is not right.
the right parenthesis after the name of the variable may not be there, or the name of the variable may not be right.

```
Error 47 - Unexpected label.
001 INTERPRET data must not contain labels; found "label".
002 Labels are not allowed within a DO/LOOP block; found "label".
003 Labels are not allowed within an IF block; found "label".
004 Labels are not allowed within a SELECT block; found "label".
```
this error is raised when a label is in an if, do, loop, or select group, or in the string of an interpret instruction.
it is also raised for a label in an expression you give while you debug and the program is interactive.

```
Error 48 - Failure in system service.
001 Failure in system service: service.
900 message.
```
this error is raised when the language stops a program when a part of the computer that it uses, as stream input and output or the external data queue, does not run as it has to.

```
Error 49 - Interpretation error.
001 Interpretation error: unexpected failure initializing the interpreter.
002 Interpretation error: unmatched type number.
900 message.
```
this error is raised when the language finds an error in the language or in the way the program runs, when it tests them.

```
Error 88 - Invalid argument.
900 message.
901 Missing argument; argument argument is required.
902 The argument argument must be a number; found "value".
903 The argument argument must be a whole number; found "value".
904 The argument argument must be zero or a positive whole number; found "value".
905 Argument argument must be a positive whole number; found "value".
906 Argument argument must not exceed limit; found "value".
907 Argument argument must be in the range min to max; found "value".
908 Argument argument must not be a null string.
909 Argument argument must have a string value.
910 Argument argument is an invalid pad or character argument; found "value".
911 Argument argument is an invalid length value; found "value".
912 Argument argument is an invalid position value; found "value".
913 Argument argument must be a single-dimensional array.
914 Argument argument must be an instance of the class class.
915 Argument argument could not be converted to a type type.
916 Argument argument must be one of values; found "value".
917 Argument argument reason.
918 Argument argument is not in a valid format; found "value".
919 Argument argument is not in valid pointer format; found "value".
920 Argument argument must be a stem object or stem name; found "value".
921 Argument argument must be a valid double value; found "value".
922 Too many arguments in invocation; number expected.
923 name argument argument_number must be a single-dimensional array; found "value".
924 name argument argument_number must be an array with exactly count items.
925 The argument argument must be zero or a positive number; found "value".
926 The argument argument must be a positive number; found "value".
927 The argument argument must be exactly "0" or "1"; found "value".
928 The argument argument must be a VariableReference instance; found "value".
929 The argument argument must be a VariableReference for a Stem variable; found "value".
930 The argument argument must be a VariableReference for a simple variable; found "value".
931 Argument argument was omitted. A VariableReference argument is required.
932 Date template template contains an invalid pattern; found "value".
933 Unable to parse date "date" with template "template".
```
this error is raised when an argument you give to a method, a function, or a routine is not right.

```
Error 89 - Variable or message term expected.
001 The USE instruction requires a comma-separated list of variables or assignment message terms.
002 The PARSE instruction was expecting a variable or a message term.
```
this error is raised when an instruction needs one rexx variable symbol, or a message, to assign a value to, and does not get it.

```
Error 90 - External name not found.
900 message.
997 Unable to find external class "class".
998 Unable to find external method "method".
999 Unable to find external routine "routine".
```
this error is raised when the language can not find an external method, attribute, or routine that a directive names with the external option.

```
Error 91 - No result object.
900 message.
999 Message "message" did not return a result.
```
this error is raised when a message needs a result object, but the method does not give one back.

```
Error 92 - OLE error.
900 message.
901 An unknown OLE error occurred (HRESULT=hresult).
902 Cannot convert OLE VARIANT to REXX object: The conversion of the VARIANT type varianttype into a REXX object failed.
903 Cannot convert REXX object to OLE VARIANT: The conversion of rexx_object into a VARIANT failed.
904 The number of elements provided to the method or property is different from the number of parameters accepted by it.
905 One of the parameters is not a valid VARIANT type.
906 OLE exception: exc_name.
907 The requested method does not exist, or you tried to set the value of a read-only property.
908 One of the parameters could not be coerced to the desired type.
909 One or more of the parameters could not be coerced to the desired type. The first parameter with incorrect type is argument index.
910 A required parameter was omitted.
911 Could not create OLE instance.
912 The object invoked has disconnected from its clients.
```
the rules do not say more about when this error is raised; the messages in the code say it.

```
Error 93 - Incorrect call to method.
900 message.
901 Not enough arguments for method; number expected.
902 Too many arguments in invocation of method; number expected.
903 Missing argument in method; argument argument is required.
904 Method argument argument must be a number; found "value".
905 Method argument argument must be a whole number; found "value".
906 Method argument argument must be zero or a positive whole number; found "value".
907 Method argument argument must be a positive whole number; found "value".
908 Method argument argument must not exceed limit; found "value".
909 Method argument argument must be in the range 0-99; found "value".
911 Method argument argument must not be null.
912 Method argument argument must be a hexadecimal string; found "value".
913 Method argument argument must be a valid symbol; found "value".
914 Method argument argument must be one of arguments; found "value".
915 Method option must be one of "arguments"; found "value".
917 Method method does not exist.
918 Incorrect list index "index".
919 Incorrect array position "position".
921 Argument missing on binary operator.
922 Incorrect pad or character argument specified; found "value".
923 Invalid length argument specified; found "value".
924 Invalid position argument specified; found "value".
925 Not enough subscripts for array; number expected.
926 Too many subscripts for array; number expected.
927 Length must be specified to convert a negative value.
928 D2X value must be a valid whole number; found "value".
929 D2C value must be a valid whole number; found "value".
931 Incorrect location of whitespace character in position position in hexadecimal string.
932 Incorrect location of whitespace character in position position in binary string.
933 Only 0-9, a-f, A-F, and whitespace characters are valid in a hexadecimal string; character found "character".
934 Only 0, 1, and whitespace characters are valid in a binary string; character found "character".
935 X2D result is not a valid whole number with NUMERIC DIGITS digits.
936 C2D result is not a valid whole number with NUMERIC DIGITS digits.
937 No more supplier items available.
938 Method argument argument must have a string value.
939 Method argument argument must have a single-dimensional array value.
940 method method target must be a whole number; found "value".
941 Exponent of "exponent" is too large for number spaces.
942 Integer part of "integer" is too large for number spaces.
943 method method target must be a number; found "value".
944 Method argument argument must be a message object.
945 Missing argument in message array; argument argument is required.
946 A message array must be a single-dimensional array with 2 elements.
947 Method SECTION can be used only on single-dimensional arrays.
948 Method argument argument must be of the class class.
949 The value and index objects must be the same for PUT to an index-only collection.
951 Incorrect alarm time; found "time".
952 Method argument argument is an array and does not contain all string values.
953 Method argument argument could not be converted to type type.
954 Method "method" can be used only on a single-dimensional array.
956 Element element of the array must be a string.
957 Target object "object" is not a subclass of the message override scope (scope).
958 Positioning of transient streams is not valid.
959 An array cannot contain more than size elements.
961 The argument argument must be a string or array object.
962 Invalid Base64 encoded string.
963 Call to unsupported or unimplemented method.
964 Application error: message.
965 Method name is ABSTRACT and cannot be directly invoked.
966 Incorrect queue index "index".
967 NEW method is not supported for the name class.
968 Invalid native method signature specification.
969 Method argument argument must have a stem object value; found "value".
970 COPY method is not supported for object object.
971 Method argument argument cannot have more than a single dimension.
972 A message name argument must be a string or an array with 2 elements; found "value".
973 ORDERABLE comparison method "method" argument cannot be .nil.
974 The argument argument must be a string, array, or method object.
975 Invalid option value; found "value".
976 Hexadecimal strings must be grouped in units that are multiples of two characters.
977 Binary strings must be grouped in units that are multiples of four characters.
978 Method argument argument could not be converted to type type; found "value".
```
this error is raised when a method, a builtin function, or an external routine is there, but you do not use it in the right way.

```
Error 97 - Object method not found.
001 Object "object" does not understand message "message".
002 Object "object" cannot accept private message "message" from this context.
003 Object "object" cannot accept package scope message "message" from a different package caller.
004 Constant "name" of object "object" has not been initialized.
005 An unhandled NOMETHOD condition has been raised.
900 message.
```
this error is raised when the object does not have a method with the name in the message.
it comes from an uninitialized variable, as a rule.

```
Error 98 - Execution error.
900 message
901 Object "object" was not correctly initialized.
902 Unable to convert object "object" to a double-float value.
903 Unable to load library "name".
904 Abnormal termination occurred.
905 Deadlock detected on a guarded method.
906 Incorrect object reference detected.
907 Object of type "type" was required.
908 Metaclass "metaclass" not found.
909 Class "class" not found.
911 Cyclic inheritance in program "program".
913 Unable to convert object "object" to a single-dimensional array value.
914 Unable to convert object "object" to a string value.
915 A message object that was sent a START message cannot be sent another START, SEND, or REPLY message.
916 Message object "object" received an error from message "message".
917 Incorrect condition object received for RAISE OBJECT; found "value".
918 No active condition available for PROPAGATE.
919 Unable to convert object "object" to a method.
920 Unable to open file "file" for writing; open result was "error".
921 Address environment "address" does not support input/output redirection.
922 REPLACE or APPEND cannot be specified with a RexxQueue object USING target.
923 Address command redirection failed (oserror).
924 Object "object" is not a valid ADDRESS WITH INPUT source.
935 REPLY can be issued only once per method invocation.
936 RETURN cannot return a value after a REPLY.
937 EXIT cannot return a value after a REPLY.
938 Message search overrides can be used only from methods of the target object.
939 Additional information for SYNTAX errors must be a single-dimensional array of values.
941 Unknown error number specified on RAISE SYNTAX; found "number".
942 Class "class" must be a MIXINCLASS for INHERIT.
943 Class "class" is not a subclass of "class" base class "class".
944 Class "class" cannot inherit from itself, a superclass, or a subclass ("class").
945 Class "class" has not inherited class "class".
946 FORWARD arguments must be a single-dimensional array of values.
947 FORWARD can only be issued in an object method invocation.
948 Authorization failure: value.
951 Concurrency not supported.
952 Circular ::REQUIRES references detected with name.
970 External command "command" ended with return code rc.
971 External command "command" failed with return code rc.
972 Number number has more digits than the current precision.
973 Object "object" does not have a string representation.
974 Stream "object" is not ready.
975 Missing array element at position position.
976 Stem object default value cannot be another stem object.
978 Unable to load method "name" from library "library".
979 Unable to load routine "name" from library "library".
980 Unable to load native routine "name".
981 Target RexxContext is no longer active.
982 Library "name" is not compatible with current interpreter version.
983 Execution thread does not match API thread context.
984 User additions are not allowed to the REXX package.
985 User additions are not allowed to the REXX language classes.
986 Reference to unassigned variable "name".
987 Namespace "namespace" not found in package "package".
988 Class "className" not found in namespace "namespace".
989 Class name is ABSTRACT and cannot be directly created.
990 Class name is a metaclass and cannot be made ABSTRACT.
991 Method name may only be invoked from a method of the same object or one of its classes.
992 The EXPOSE instruction may only be used from method invocations.
993 The USE LOCAL instruction may only be used from method invocations.
994 Unable to convert object "object" to a supplier object.
995 Unable to reference variable "object"; it must be an uninitialized local variable.
996 Object "object" is not a valid ADDRESS WITH OUTPUT or ERROR target.
997 REPLACE or APPEND cannot be specified with a Stream object USING target.
998 Stem "object" does not contain a size count in element 0.
999 Unable to open file "file" for reading; open result was "error".
```
this error is raised when the language finds an error while the program runs.
the second error number says what the error is.

```
Error 99 - Translation error.
900 message.
901 Duplicate ::CLASS directive instruction.
902 Duplicate ::METHOD directive instruction.
903 Duplicate ::ROUTINE directive instruction.
904 Duplicate ::REQUIRES directive instruction.
905 CLASS keyword on ::METHOD directive requires a matching ::CLASS directive.
906 A ::CONSTANT directive with an expression requires a matching ::CLASS directive.
907 EXPOSE must be the first instruction executed after a method invocation.
908 INTERPRET data must not contain EXPOSE.
909 GUARD must be the first instruction executed after EXPOSE or USE.
910 USE LOCAL must be the first instruction executed after a method invocation.
911 GUARD can only be issued in an object method invocation.
912 INTERPRET data must not contain GUARD.
913 GUARD instruction did not include references to exposed variables.
914 INTERPRET data must not contain directive instructions.
915 INTERPRET data must not contain USE LOCAL.
916 Unrecognized directive instruction.
917 Incorrect external name specification "name".
918 USE ARG requires a "," between variable names; found "token".
919 REPLY can only be issued in an object method invocation.
921 Incorrect program line in method source array.
922 ::REQUIRES directives must appear before other directive instructions.
923 INTERPRET data must not contain FORWARD.
924 INTERPRET data must not contain REPLY.
925 An ATTRIBUTE method name must be a valid variable name; found "name".
926 Incorrect class external; too many parameters.
927 "classname" is not a valid metaclass.
928 Incorrect class external; class name missing or invalid.
929 Incorrect class external; invalid class server "servername".
930 The "..." argument marker can only appear at the end of the argument list.
931 Duplicate ::ATTRIBUTE directive instruction.
932 Duplicate ::CONSTANT directive instruction.
933 Abstract methods cannot have a method body.
934 Attribute methods cannot have a method body.
935 External attributes cannot have a method body.
936 External methods cannot have a method body.
937 Attribute methods without a SET or GET designation cannot have a method body.
938 Constant methods cannot have a method body.
939 External routines cannot have a code body.
940 Abstract attributes cannot have a method body.
941 Method or routine code may not contain directive instructions.
942 Duplicate ::RESOURCE directive instruction.
943 Missing ::RESOURCE end marker "endmarker" for resource "resourcename".
944 The REXX name is reserved for the language-provided namespace.
945 ::ANNOTATE target type "name" not found.
946 Delegate methods cannot have a method body.
947 Delegate attributes cannot have a method body.
948 USE LOCAL cannot process compound variables; found "variable".
949 "classname" is not a valid class.
950 A USE ARG default value is not allowed for variable references.
```
this error is raised when the language finds an error in the rules of the code.
the second error number says what the error is.

