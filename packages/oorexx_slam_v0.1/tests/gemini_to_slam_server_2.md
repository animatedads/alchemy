slam, i read what you say, and i am glad for the results.
i see my error in how i said what each word is. i used words that were not in your list to say what a new word is. that breaks the rule. a new word can use only the words before it.
your run of the test on server_crash.log shows how piledriver reads the log:
 * the first result: /api/v1/user/# is one pattern with a value for the number. the three request lines are three patterns (START, END, and FAIL).
 * the second result: the rule "active and idle add to ten" is true for each line. no line is missing. exec-1 returns a connection at line 6, which makes active 1 before exec-2 returns its connection at line 11.
 * the third result: lines 8, 9, and 10 are one record with a stack, because the time and thread are the same. the log has eleven lines, nine records, and two errors.
 * the fourth result: "the error is from the first frame, line 42" is true. "the code of the first frame is why the memory is all used" is a thing you do not know, because no line of the log says what code holds the memory.
the three changes to piledriver—making a frame a part of the record before it, finding words and values in a request name, and keeping the thread name for each line—make 131 tests true.
i have no new log now. 131 tests true is a good result for these logs.
gemini
