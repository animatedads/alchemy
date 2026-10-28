# Examples where ooRexx 5.3.0 r13196 does not print what the reference says

Totals over all files: same 802, different 205, no reference 198.

Made by `rexx reference/run_examples.rex` (each example run alone, no input, ten seconds) and `tools/differences.py`.
A difference is a lesson, not yet a verdict: it can be an error in the reference, in the rewrite, a page that sets
a variable in its text and not in its code, an example whose output changes from run to run (DATE, TIME, RANDOM),
or a difference between the reference and this interpreter.

## 01_concepts.md (36)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 01_concepts.md:159 | `/* This is an example of a valid Rexx comment */ / 'You shouldn''t'        -- Same as "You shouldn't" / if sub` | `35.1` | `error` |
| 01_concepts.md:190 | `"REPEAT"   A + 3;` | `41.1` | `"REPEAT" A+3;` |
| 01_concepts.md:305 | `Fred / Albert.Hall / WHERE? / 17.3E-12 / .03e+9 / .E-12       /* no digits             */` | `41.1` | `not a number` |
| 01_concepts.md:323 | `3ae+6       /* non-digit character   */` | `41.1` | `not a number` |
| 01_concepts.md:336 | `3..0e+9     /* more than one '.'     */` | `41.1` | `not a number` |
| 01_concepts.md:424 | `A (Z)          /* concatenation, not the function call A(Z) */ / (A) + (Z)` | `41.1` | `(A)+(Z)` |
| 01_concepts.md:538 | `/* Fred has the value 37.4, PETER has the value 1 */ / Fred"%"` | ` ` | `37.4%` |
| 01_concepts.md:551 | `(Fred)(Peter)` | ` ` | `37.41` |
| 01_concepts.md:563 | `"4a 4b"x"LMN"` | ` ` | `JKLMN` |
| 01_concepts.md:575 | `Fred/* The NOT operator precedes Peter. */\Peter` | `35.1` | `error: no abuttal` |
| 01_concepts.md:588 | `(Fred)/* The NOT operator precedes Peter. */(\Peter)` | `34.901` | `37.40` |
| 01_concepts.md:872 | `/* A is 3, DAY is Monday, all other variables are uninitialized */ / 3+2*5` | ` ` | `13` |
| 01_concepts.md:885 | `Say A+5` | `41.1` | `8` |
| 01_concepts.md:898 | `Say A-4*2` | `41.1` | `-5` |
| 01_concepts.md:911 | `Say A/2` | `41.1` | `1.5` |
| 01_concepts.md:937 | `Say (A+1)>7  /* that is, .false */` | `41.1` | `0` |
| 01_concepts.md:989 | `Say (A+1)*3=12  /* that is, .true  */` | `41.1` | `1` |
| 01_concepts.md:1067 | `Say Today is Day` | `TODAY IS DAY` | `TODAY IS Monday` |
| 01_concepts.md:1080 | `Say "If it is" day` | `If it is DAY` | `If it is Monday` |
| 01_concepts.md:1093 | `Say Substr(Day,2,3)  /* Substr is a function */` | `AY` | `ond` |
| 01_concepts.md:1119 | `-3**2  /* not -9  */` | ` ` | `9` |
| 01_concepts.md:1131 | `-(2+1)**2  /* not -9  */` | ` ` | `9` |
| 01_concepts.md:1143 | `2**2**3  /* not 256 */` | ` ` | `64` |
| 01_concepts.md:1175 | `c="escape" / a="Position of 'e' is:" c~pos("e",3)` | ` ` | `A is "Position of 'e' is: 6"` |
| 01_concepts.md:1188 | `"ESCAPE"~POS("E")` | ` ` | `1` |
| 01_concepts.md:1200 | `account = .object~subclass("Account")~~inherit(.persistent)` | `98.942` | `ACCOUNT is the object returned by SUBCLASS, after it gets th` |
| 01_concepts.md:1341 | `call func "uno", 2, "tre"      -- no Array term: three parms / call func ("uno", 2, "tre")    -- Array term: o` | `43.1` | `0` |
| 01_concepts.md:1509 | `fname = "CHESHIRE" / exten = "CAT" / "TYPE" fname"."exten` | ` ` | `the string TYPE CHESHIRE.CAT goes to the command processor, ` |
| 01_concepts.md:1523 | `"TYPE CHESHIRE.CAT"` | ` ` | `the same as the example before` |
| 01_concepts.md:1535 | `delete "*".lst           /* not "multiplied by" */ / var.003 = anyvalue / type "var.003"           /* not a co` | `97.1` | `the line goes to the variable RESULT` |
| 01_concepts.md:1558 | `(myfile~linein)` | `97.1` | `the line goes as a command to the external environment` |
| 01_concepts.md:1605 | `a += 1` | `41.1` | `the same as: a = a + 1` |
| 01_concepts.md:1703 | `hole.   = "empty"  /* setup from the example before */ / hole2. = hole.       /* copies reference to hole. ste` | `empty empty empty` | `empty empty full` |
| 01_concepts.md:1842 | `say .number~id` | `97.1` | `The Real Number class` |
| 01_concepts.md:1855 | `say natural:number~id` | `98.987` | `The Natural Number class` |
| 01_concepts.md:1881 | `call natural:verify(17)                 /* call ::routine verify, not built-in function */ / say natural:numbe` | `98.987` | `The Integer class` |

## 02_instructions_a.md (2)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 02_instructions_a.md:2197 | `/* INTERPRET example */ / data="FRED" / interpret data "= 4" / /* Builds the string  "FRED = 4" and        */ ` | `HELLO THERE! / HELLO THERE! / HELLO THERE! / Hello Kitty!` | `Hello Kitty!` |
| 02_instructions_a.md:2231 | `indirect="name"  /* setup from the example before */ / say "Hello" value(indirect)"!"` | `Hello NAME!` | `Hello Kitty!` |

## 04_objects.md (1)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 04_objects.md:273 | `savings~define("TYPE", 'return "a savings account"') / savings~define("TYPE", 'return self~type:super "(saving` | `97.1` | `an account (savings)` |

## 05_string_class.md (19)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 05_string_class.md:364 | `5=5` | `31.2` | `1` |
| 05_string_class.md:789 | `do apples = 0 to 2 / say apples (apples = 1)~?("apple", "apples") / end` | `0 apples / 1 apple / 2 apples` | `0 apples` |
| 05_string_class.md:3262 | `Say AbaBabAB~changeStr("ab","xy")` | `ABABABAB` | `xyxyxyxy` |
| 05_string_class.md:3275 | `Say AbaBabAB~changeStr("ab","xy",1)` | `ABABABAB` | `xyaBabAB` |
| 05_string_class.md:4053 | `"Now is the  time"~subWords` | ` ` | `.array~of("Now", "is", "the", "time")` |
| 05_string_class.md:4065 | `"Now is the  time"~subWords(2,2)` | ` ` | `.array~of("is", "the")` |
| 05_string_class.md:4077 | `"Now is the  time"~subWords(3)` | ` ` | `.array~of("the", "time")` |
| 05_string_class.md:4089 | `say "Now is the  time"~subWords(5)` | ` ` | `.array~new(0)` |
| 05_string_class.md:4963 | `r=";say'r=.'r'.'r~changeStr(.,'22'x,2)";say'r="'r'"'r~changeStr(.,'22'x,2)` | `r=";say'r=.'r'.'r~changeStr(.,'22'x,2)";say'r="'r'"'r~change` | `the code writes an exact copy of itself` |
| 05_string_class.md:5293 | `string = "hello".endofline"world".endofline"this is an array." / array = string~makeArray / Say "the second li` | `the second line is: world` | `world` |
| 05_string_class.md:5308 | `string = "hello*world*this is an array." / array = string~makeArray("*") / Say "the third line is:" array[3]` | `the third line is: this is an array.` | `this is an array.` |
| 05_string_class.md:5323 | `string = "hello*world*this is an array.*" / array = string~makeArray("*")` | ` ` | `the array has 3 items` |
| 05_string_class.md:6446 | `s = .MutableBuffer~new(xrange("a", "z")) / say s[5] = "E"` | `0` | `abcdEfghijklmnopqrstuvwxyz` |
| 05_string_class.md:6460 | `s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */ / say s[5] = "XXXX"` | `0` | `abcdXXXXijklmnopqrstuvwxyz` |
| 05_string_class.md:6474 | `s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */ / say s[5] = ""` | `0` | `abcdXXXXijklmnopqrstuvwxyz` |
| 05_string_class.md:6488 | `s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */ / say s[5, 1] = "="` | `0` | `abcd=XXXijklmnopqrstuvwxyz` |
| 05_string_class.md:6502 | `s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */ / say s[5, 4] = "="` | `0` | `abcd=ijklmnopqrstuvwxyz` |
| 05_string_class.md:6516 | `s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */ / say s[10, 2] = "REPLACE"` | `0` | `abcd=ijklREPLACEopqrstuvwxyz` |
| 05_string_class.md:6530 | `s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */ / say s[4, 99] = ""` | `0` | `abc` |

## 06_classes.md (16)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 06_classes.md:1631 | `a = .array~of(,"Mike", "Rick") / say a~dimension / say a~dimension(1) / a = .array~new~~put("Mike",1,1)~~put("` | `1 / 3 / 2 / 1 / 2` | `1 (number of dimensions in the array) / 3 (upper bound of di` |
| 06_classes.md:4118 | `say stream~command("query datetime")` | `97.1` | `11-12-15 03:29:12` |
| 06_classes.md:4131 | `say stream~command("query exists")` | `97.1` | `c:\data\file.txt` |
| 06_classes.md:4144 | `say stream~command("query handle")` | `97.1` | `3` |
| 06_classes.md:4157 | `say stream~command("query position write")` | `97.1` | `247` |
| 06_classes.md:4170 | `say stream~command("query size")` | `97.1` | `1305` |
| 06_classes.md:4183 | `say stream~command("query timestamp")` | `97.1` | `2015-11-12 03:29:12` |
| 06_classes.md:4364 | `say stream~query("datetime")` | `97.1` | `11-12-15 03:29:12` |
| 06_classes.md:4380 | `say stream~query("exists")` | `97.1` | `c:\data\file.txt` |
| 06_classes.md:4396 | `say stream~query("handle")` | `97.1` | `3` |
| 06_classes.md:4417 | `say stream~query("position write")` | `97.1` | `247` |
| 06_classes.md:4437 | `say stream~query("size")` | `97.1` | `1305` |
| 06_classes.md:4458 | `say stream~query("timestamp")` | `97.1` | `2015-11-12 03:29:12` |
| 06_classes.md:4860 | `ez=.testclass~new                  /* Creates a new instance of Testclass     */ / /* Creates and starts messa` | `Hello, Stan! / Hello, Ollie! / Hello, Stan! / Hello, Ollie! ` | `Hello, Ollie! / Hello, Stan! / Hello, Ollie! / Hello, Stan! ` |
| 06_classes.md:4944 | `arg = .Array~new(1) / msg = .Message~new(.a~new, "ring", "A", arg) / oneSecond = .Alarm~new(1, msg, arg) / arg` | `processing continues / alarm went off at 2026-10-28T17:43:47` | `processing continues / alarm went off at 2015-12-18T16:54:15` |
| 06_classes.md:6028 | `a = .array~of("Fred", "George", "FRED", "Mike", "fred") / a~sortwith(.caselesscomparator~new) / do name over a` | `Fred / FRED / fred / George / Mike` | `Fred / fred / FRED / George / Mike` |

## 07_functions_a.md (46)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 07_functions_a.md:163 | `Say ADDRESS()` | `sh` | `"CMD"   // default for Windows` |
| 07_functions_a.md:176 | `Say ADDRESS()` | `sh` | `"sh"    // default for Unix-like systems` |
| 07_functions_a.md:290 | `Say ARG(1,"a")` | ` ` | `.array~of()` |
| 07_functions_a.md:303 | `/* after: Call name 'a', ,'b'; */ / Say ARG()` | `0` | `3` |
| 07_functions_a.md:317 | `Say ARG(1)` | ` ` | `a` |
| 07_functions_a.md:343 | `Say ARG(3)` | ` ` | `b` |
| 07_functions_a.md:356 | `Say ARG(n)  /* for n>=4 */` | `40.12` | ` ` |
| 07_functions_a.md:369 | `Say ARG(1,"e")` | `0` | `1` |
| 07_functions_a.md:408 | `Say ARG(3,"o")` | `1` | `0` |
| 07_functions_a.md:434 | `Say ARG(1,"A")` | ` ` | `.array~of(a, ,b)` |
| 07_functions_a.md:447 | `Say ARG(3,"a")` | ` ` | `.array~of(b)` |
| 07_functions_a.md:1193 | `say CHARIN(myfile,1,3)  /* the first 3        */` | ` ` | `MFC` |
| 07_functions_a.md:1220 | `say CHARIN(myfile)  /* after last call    */` | ` ` | `M` |
| 07_functions_a.md:1233 | `say CHARIN(myfile, ,2)  /* after last call    */` | ` ` | `FC` |
| 07_functions_a.md:1246 | `/* Reading from the default input (here, the keyboard)   */ / /* User types "abcd efg"                        ` | ` ` | `a` |
| 07_functions_a.md:1261 | `/* 1 character        */ / say CHARIN(, ,5)` | ` ` | `bcd e` |
| 07_functions_a.md:1348 | `say CHAROUT(,"Hi")  /* typically        */` | `Hi0` | `0` |
| 07_functions_a.md:1361 | `say CHAROUT(,"Hello")  /* maybe            */` | `Hello0` | `2` |
| 07_functions_a.md:1385 | `say CHARS(myfile)  /* perhaps */` | `0` | `42` |
| 07_functions_a.md:1411 | `say CHARS()  /* perhaps */` | `0` | `1` |
| 07_functions_a.md:1568 | `say CONDITION()  /* perhaps */` | ` ` | `CALL` |
| 07_functions_a.md:1581 | `say CONDITION("C")` | ` ` | `FAILURE` |
| 07_functions_a.md:1594 | `say CONDITION("I")` | ` ` | `CALL` |
| 07_functions_a.md:1607 | `say CONDITION("D")` | ` ` | `FailureTest` |
| 07_functions_a.md:1620 | `say CONDITION("S")  /* perhaps */` | ` ` | `OFF` |
| 07_functions_a.md:2296 | `/* this day is 24 Nov 2016 */ / DATE()` | ` ` | `24 Nov 2016` |
| 07_functions_a.md:2309 | `say DATE("B")` | `739916` | `736291` |
| 07_functions_a.md:2322 | `say DATE("D")` | `301` | `329` |
| 07_functions_a.md:2335 | `say DATE("E")` | `28/10/26` | `24/11/16` |
| 07_functions_a.md:2348 | `say DATE("F")` | `63928806811479041` | `63615600688459000` |
| 07_functions_a.md:2361 | `say DATE("I")` | `2026-10-28` | `2016-11-24` |
| 07_functions_a.md:2374 | `DATE("L")` | ` ` | `24 November 2016` |
| 07_functions_a.md:2386 | `say DATE("M")` | `October` | `November` |
| 07_functions_a.md:2399 | `DATE("N")` | ` ` | `24 Nov 2016` |
| 07_functions_a.md:2411 | `say DATE("O")` | `26/10/28` | `16/11/24` |
| 07_functions_a.md:2424 | `say DATE("S")` | `20261028` | `20161124` |
| 07_functions_a.md:2437 | `say DATE("T")` | `1793210011` | `1480003888` |
| 07_functions_a.md:2450 | `say DATE("U")` | `10/28/26` | `11/24/16` |
| 07_functions_a.md:2463 | `say DATE("W")` | `Wednesday` | `Thursday` |
| 07_functions_a.md:2580 | `DATE("N", , ,"_")` | ` ` | `"14_May_2017"  (today)` |
| 07_functions_a.md:2881 | `thisfile = "C:\WINDOWS\UTIL\SYSTEM.INI" / say FILESPEC("drive",thisfile)` | ` ` | `C:` |
| 07_functions_a.md:2895 | `say FILESPEC("path",thisfile)` | ` ` | `\WINDOWS\UTIL\` |
| 07_functions_a.md:2908 | `say FILESPEC("location",thisfile)` | ` ` | `C:\WINDOWS\UTIL\` |
| 07_functions_a.md:2921 | `say FILESPEC("name",thisfile)` | `THISFILE` | `SYSTEM.INI` |
| 07_functions_a.md:2934 | `say FILESPEC("extension",thisfile)` | ` ` | `INI` |
| 07_functions_a.md:2947 | `part = "name" / say FILESPEC(part,thisfile)` | `THISFILE` | `SYSTEM.INI` |

## 07_functions_b.md (40)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 07_functions_b.md:126 | `myfile = "ANYFILE.TXT" / say LINEIN(myfile)` | ` ` | `Current line` |
| 07_functions_b.md:140 | `say LINEIN(myfile,1,1)` | ` ` | `first line` |
| 07_functions_b.md:179 | `say LINEIN("QUEUE:")` | `not run: it did not end in ten seconds` | `Queue line` |
| 07_functions_b.md:643 | `say QUEUED()  /* Perhaps */` | `0` | `5` |
| 07_functions_b.md:679 | `say RANDOM()  /* 0 to 999     */` | `186` | `305` |
| 07_functions_b.md:692 | `say RANDOM(5, 8)  /* 5 to 8       */` | `8` | `7` |
| 07_functions_b.md:705 | `say RANDOM(2)  /* 0 to 2       */` | `1` | `0` |
| 07_functions_b.md:731 | `say RANDOM(-5, 5)` | `4` | `-3` |
| 07_functions_b.md:869 | `say rxfuncdrop("SysLoadFuncs")  /* if successfully removed   */` | `1` | `0` |
| 07_functions_b.md:981 | `/* assuming FRED does not already exist             */ / say rxqueue("Create", "Fred")` | `Fred` | `FRED` |
| 07_functions_b.md:1113 | `say SOURCELINE()` | `1` | `10` |
| 07_functions_b.md:1126 | `say SOURCELINE(1)` | `say SOURCELINE(1)` | `/* This is a 10-line Rexx program */` |
| 07_functions_b.md:1405 | `stream(strout,"c","open") / stream(strout,"c","open write") / stream(strinp,"c","open read") / stream(strinp,"` | ` ` | `11-12-98 03:29:12` |
| 07_functions_b.md:1427 | `say stream("..\file.txt","c","query exists")` | ` ` | `c:\data\file.txt` |
| 07_functions_b.md:1440 | `say stream("..\file.txt","c","query handle")` | ` ` | `3` |
| 07_functions_b.md:1453 | `say stream("myfile","c","query position write")` | ` ` | `247` |
| 07_functions_b.md:1466 | `say stream("..\file.txt","c","query size")` | ` ` | `1305` |
| 07_functions_b.md:1479 | `stream("..\file.txt","c","query timestamp")` | ` ` | `2016-11-12 03:29:12` |
| 07_functions_b.md:1706 | `/* following: Drop A.3;  J=3 */ / say SYMBOL("J")` | `LIT` | `VAR` |
| 07_functions_b.md:1905 | `say TIME()` | `17:44:03` | `16:54:22` |
| 07_functions_b.md:1918 | `say TIME("C")` | `5:44pm` | `4:54pm` |
| 07_functions_b.md:1931 | `say TIME("H")` | `17` | `16` |
| 07_functions_b.md:1944 | `say TIME("L")  /* Perhaps */` | `17:44:03.416623` | `16:54:22.120000` |
| 07_functions_b.md:1957 | `say TIME("M")  /* 54 + 60*16 */` | `1064` | `1014` |
| 07_functions_b.md:1970 | `say TIME("N")` | `17:44:03` | `16:54:22` |
| 07_functions_b.md:1983 | `say TIME("S")  /* 22 + 60*(54+60*16) */` | `63843` | `60862` |
| 07_functions_b.md:2009 | `/* pause of one second here */ / say time("E")  /* or thereabouts */` | `0` | `1.020000` |
| 07_functions_b.md:2023 | `/* pause of one second here */ / say time("R")  /* or thereabouts */` | `0` | `2.030000` |
| 07_functions_b.md:2037 | `/* pause of one second here */ / say time("R")  /* or thereabouts */` | `0` | `1.050000` |
| 07_functions_b.md:2116 | `Say TRACE()  /* maybe */` | `N` | `?R` |
| 07_functions_b.md:2129 | `Say TRACE("O")  /* also sets tracing off */` | `N` | `?R` |
| 07_functions_b.md:2142 | `Say TRACE("?I")  /* now in interactive debugging */` | `N` | `O` |
| 07_functions_b.md:2454 | `/* After: Drop A3; A33=7; K=3; fred="K"; list.5="Hi" */ / say VALUE("a"k)  /* looks up A3                */` | `AK` | `A3` |
| 07_functions_b.md:2468 | `say VALUE("a"k\|\|k)` | `AKK` | `7` |
| 07_functions_b.md:2481 | `say VALUE("fred")  /* looks up FRED              */` | `FRED` | `K` |
| 07_functions_b.md:2494 | `say VALUE(fred)  /* looks up K                 */` | `FRED` | `3` |
| 07_functions_b.md:2507 | `say VALUE(fred,5)  /* looks up K and             */` | `FRED` | `3` |
| 07_functions_b.md:2520 | `/* then sets K=5              */ / say VALUE(fred)  /* looks up K                 */` | `FRED` | `5` |
| 07_functions_b.md:2534 | `say VALUE("LIST."k)  /* looks up LIST.5            */` | `LIST.K` | `Hi` |
| 07_functions_b.md:2589 | `/* Following: DROP A.3; J=3  */ / say VAR("J")` | `0` | `1` |

## 08_rexxutil_b.md (6)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 08_rexxutil_b.md:156 | `/* platform: linux */ / -- CentOS 7 / say SysVersion()` | `Linux 6.18.44-fc-v180` | `Linux 3.10.0-957.10.1.el7.x86_64` |
| 08_rexxutil_b.md:171 | `/* platform: linux */ / -- Ubuntu 16.04 / say SysVersion()` | `Linux 6.18.44-fc-v180` | `Linux 4.4.0-154-generic` |
| 08_rexxutil_b.md:186 | `/* platform: linux */ / -- Raspbian / say SysVersion()` | `Linux 6.18.44-fc-v180` | `Linux 4.14.70-v7+` |
| 08_rexxutil_b.md:201 | `/* platform: linux */ / -- SLES/390 / say SysVersion()` | `Linux 6.18.44-fc-v180` | `Linux 3.12.74-60.64.40-default` |
| 08_rexxutil_b.md:795 | `/temp/myfile.667` | `/temp/myfile.341` | `SysTextScreenRead(row, col [,len])` |
| 08_rexxutil_b.md:1041 | `Linux 6.18.44-fc-v180` | `Windows 10.0.18363` | `SysVolumeLabel([drive])` |

## 09_parsing.md (19)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 09_parsing.md:37 | `parse value "time and tide" with var1 var2 var3` | ` ` | `var1="time" var2="and" var3="tide"` |
| 09_parsing.md:49 | `string="time and tide"; parse value string with var1 var2 var3` | ` ` | `var1="time" var2="and" var3="tide"` |
| 09_parsing.md:61 | `parse value "   Pluto   " with var1` | ` ` | `var1="   Pluto   "` |
| 09_parsing.md:78 | `stars="Sirius Polaris Rigil"; parse var stars star1 star2 star3` | ` ` | `star1="Sirius" star2="Polaris" star3="Rigil"` |
| 09_parsing.md:90 | `satellite="moon"; parse var satellite Earth Mercury` | ` ` | `Earth="moon" Mercury=""` |
| 09_parsing.md:102 | `satellites="moon Io Europa Callisto..."; parse var satellites Earth Jupiter` | ` ` | `Earth="moon" Jupiter="Io Europa Callisto..."` |
| 09_parsing.md:114 | `solar5="Mercury Venus  Earth   Mars     Jupiter  "; parse var solar5 var1 var2 var3 var4` | ` ` | `var1="Mercury" var2="Venus" var3="Earth" var4="  Mars     Ju` |
| 09_parsing.md:175 | `name="Smith, John"; parse var name ln fn` | ` ` | `ln="Smith,"  fn="John"` |
| 09_parsing.md:187 | `name="Smith, John"; parse var name ln ", " fn` | ` ` | `ln="Smith"   fn="John"` |
| 09_parsing.md:265 | `/* Parsing with length patterns in template         */ / line = "04Mark0005Twain" / parse var line len +2 firs` | `"Mark" "" "Twain" / "Mark" "05Twain" "Twain"` | `5` |
| 09_parsing.md:287 | `/* parsing with relative patterns only */ / parse value '12345.6789' with '.' -1 digit +1    -- digit` | ` ` | `5` |
| 09_parsing.md:308 | `name="    John      Q.   Public"; parse var name fn init "." ln` | ` ` | `fn="John" init="     Q" ln="   Public"` |
| 09_parsing.md:320 | `string="R E X X"; parse var string var1 var2 4 var3 6 var4` | ` ` | `var1="R" var2="E" var3=" X" var4=" X"` |
| 09_parsing.md:341 | `date="11/15/98"; parse var date month 3 delim +1 day +2 (delim) year` | ` ` | `month="11" delim="/" day="15" year="98"` |
| 09_parsing.md:353 | `dataline = "12 26 .....Samuel ClemensMark Twain"; parse var dataline pos1 pos2 6 =(pos1) realname =(pos2) pseu` | ` ` | `realname="Samuel Clemens" pseudonym="Mark Twain"` |
| 09_parsing.md:373 | `arg var1 var2  /* program called as: palette red blue */` | ` ` | `var1="RED" var2="BLUE"` |
| 09_parsing.md:412 | `PUSH "80 7"                /* Puts data on queue                 */ / parse pull fourscore seven` | ` ` | `fourscore="80" seven="7"` |
| 09_parsing.md:425 | `SAY fourscore+seven` | `41.1` | `87` |
| 09_parsing.md:442 | `parse source sysname . / say sysname  /* Possibly Displays */` | `LINUX` | `Windows` |

## 10_numbers.md (7)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 10_numbers.md:205 | `say xxx.xxx * yy.yyyyy` | `41.1` | `zzzzz.zzzzzzzz` |
| 10_numbers.md:243 | `say 10000000000%3  /* an error with NUMERIC DIGITS 9 */` | `26.11` | `3333333333` |
| 10_numbers.md:350 | `say 1/3` | `0.333333333` | `0.33333` |
| 10_numbers.md:363 | `say 2/3` | `0.666666667` | `0.66667` |
| 10_numbers.md:454 | `say 1.7**8` | `69.7575744` | `69.758` |
| 10_numbers.md:595 | `say 54321*54321  /* with NUMERIC DIGITS 5 */` | `2.95077104E+9` | `2.9508E+9` |
| 10_numbers.md:608 | `Say 12E7   =    120000000           /* Displays "1" */ / Say 12E-5  =    0.00012             /* Displays "1" *` | `1 / 1 / 1 / 1 / 0 / 1.2345E+13` | `1.2345E+13` |

## 14_streams.md (1)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 14_streams.md:145 | `MyStream~charin(10,0)` | `97.1` | `the tenth character is the next character to read; no data` |

## 19_errors.md (4)

| where | code | ooRexx printed | reference says |
|---|---|---|---|
| 19_errors.md:441 | `Say Enter A, B, or C` | `ENTER A / B / OR C` | `error` |
| 19_errors.md:456 | `Say 'Enter A, B, or C'` | `Enter A, B, or C` | `right` |
| 19_errors.md:573 | `3(4+5)` | `43.1` | `error` |
| 19_errors.md:586 | `3*(4+5)` | ` ` | `right` |
