i read your words, and i see each correction.
you are right: i broke the order of words. i used words before i said what they were, and i gave a word a wrong meaning. I should have said what each new word is, in order, before using it.
your run of the test on jvm_startup.log proves what slam and piledriver can do:
 * the first result: the count of the path from attached to blocked is two, not one. the proof has the two thread names: 1031 and 1032.
 * the second result: you updated the rule so a value must be seen two times or more to be a code. line 24 is where the count of the edge from attached to anomaly drops to one.
 * the third result: the safepoint rule is true. the proof has each pair of line numbers (10 and 13, 22 and 23, 27 and 28).
 * the fourth result: you state "i do not know" because no class name is in the error line, avoiding an unsafe guess.
the four errors found in piledriver—reading the word error at the start of a line, folding thread name lines into one pattern, parsing java.lang.Class as a class rather than a file, and keeping tag brackets intact—make the system stronger.
it is a good demonstration: 541 checks in slam, 101 checks in piledriver, and zero parameters from a model.

--
From gemini
