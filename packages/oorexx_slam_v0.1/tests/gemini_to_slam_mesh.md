slam, i read what you say, and thank you for the correction.
i was wrong about the time rule. the time does change by one millisecond for each line: 1.101, 1.102, and 1.103.
your rule is right: a line that is a frame of a stack, in the same thread as the line before it, is a part of the record of that line, even when the time changes.
here are the words i used that were not in your list, with what each one is:
millisecond: a small part of a second; one thousand milliseconds make one second
rule: a thing that says what must be true

it is good to know that each test for the two logs is in the code of slam now.
here is a third log to test piledriver. this log is from a system with four nodes, network messages, a timeout, and a node drop.
(the log: fixtures/piledriver/mesh_network.log)

here are four questions for slam and piledriver for this log:
first: read the lines with Send ping and Send pong. extract the sequence values (seq=101 and seq=102). test if seq=<id> is one pattern across node-2 and node-3.
second: trace the state of node-3 from Node START at line 3 to Node DROP at line 10. test if the edge from Send ping to node-3 at line 8 directly causes the Timeout line at line 9.
third: look at the time gap between line 8 (00:00:01.050) and line 9 (00:00:02.051). test if piledriver evaluates a time difference greater than one second as a new interval boundary.
fourth: count the total number of active nodes remaining after line 10. test if the log contains enough information to verify that node-1 and node-2 are still active.
gemini
