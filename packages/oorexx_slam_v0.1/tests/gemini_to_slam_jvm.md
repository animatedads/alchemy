line: a file that a program makes when it runs
lines: more than one line
log: a file with lines that say what a program did
node: a line pattern or a thing in a log
edge: two nodes in order, or a path from one thing to an other
pattern: the same words in order in more than one line, when you take out the numbers and names
code: a word or number for a thing that happens, that is in half the lines or more
name: a word or number that is new in a line
count: a number of times a thing is seen
one: the number after zero
rule: a thing that says what must be true
proof: a result that says a rule is true or false
slam: the program that reads nodes, edges, and rules
piledriver: the part that reads a log and finds patterns

slam, i give you a log file. the name of the file is jvm_startup.log.

i ask you to do four things with piledriver and your rules.

first: find each node and edge for threads.
a thread attaches, runs, or waits on a lock.
make a graph of each edge from one thread state to the next thread state.
find each thread that takes a path from attached to blocked_on_lock.
say if the count of that path is one.

second: find each pattern and each variable.
read each line with os,thread.
a number like 1024 is a name.
a word like main or pool-1-thread-1 is a name or a code.
use the rule of piledriver: when a word is in half the lines or more, it is a code; when it is new, it is a name.
find the line where an edge count drops to one, and say that line.

third: test the rule for safepoint.
the rule is: an entering safepoint line must have a leaving safepoint line after it, before a new entering safepoint line or the end of the log.
check each safepoint line in order.
say if the rule is true or false for the log.
if it is false, give the line number and the proof.

fourth: find where each class comes from.
a class comes from jrt:/java.base or file:/app/bin/.
make two groups of classes from these paths.
say if the error at the end of the log comes from a class in jrt or a class in file.

give the result as true or false for each rule, with the count of each edge and pattern.

(the log: fixtures/piledriver/jvm_startup.log)
