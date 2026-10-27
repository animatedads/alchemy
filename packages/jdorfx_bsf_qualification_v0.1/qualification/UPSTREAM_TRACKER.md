# Interpreter native-API upstream tracker — checked 2026-10-27

The following SourceForge tracker entries are OPEN, not production-ready fixes:

| Ticket | Issue | Relevant qualification evidence |
|---|---|---|
| [#2116](https://sourceforge.net/p/oorexx/bugs/2116/) | A native argument error can leave a stale activation, hide CheckCondition and crash during GC. Filed by Tom Dyer 2026-10-15; the ticket expressly suggests a possible connection with an earlier BSF4ooRexx850 core dump. | The independent `bin/qualify.sh native` phase repeats the existing invalid-argument and valid-control forced-GC reproducers. Local patch passed 3/3 on r13284; upstream merge unconfirmed. |
| [#2104](https://sourceforge.net/p/oorexx/bugs/2104/) | Nested API contexts can disable active condition traps and cause a crash on a later SYNTAX error. | Negative nested callbacks are NOT_RUN by this package's positive BSF callback fixtures. |
| [#2123](https://sourceforge.net/p/oorexx/bugs/2123/) | Non-SYNTAX conditions through CallRoutine / CallProgram can be lost on r13286; decoding non-SYNTAX conditions also has a reported error path. | Non-SYNTAX negative bridge tests are NOT_RUN. |

A native positive pass or BSF Java-thread Runnable callback pass is NOT enough to qualify error propagation or JDORFX visuals/animation. Do not file another #2116 ticket. This is evidence tracking, not a claim that #2116 caused all original BSF crashes.

Existing interpreter bug reports: `animatedads/oorexx/oorexx2cpp/ootest/interpreter_bugs/BUG_REPORTS.md`; original patch report: `TICKET_bug2.md`. Other upstream fixes #2100, #2102, #2106 and #2120 are distinct.
