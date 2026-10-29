# read this first

the first list of words is here:

```
corpus/circular_corpus_v2.csv
```

## words i add

this part has the words i use that are not in the first list of words. after each word i add are the words that say what it is, and i know each word that says what it is.

slam: the name of this program
definition: the words that say what a word is
node: a part of code; two parts of code are one node if the way of each is the same, also when the words are not the same
nodes: more than one node
edge: the order of two nodes: this node, then the next node
edges: more than one edge
results: more than one result
score: a number from zero to one that i get from the results of the test of an edge; it is not more than the count of true results divide by the count of all results, and with less results it is less
scores: more than one score
prior: a chance you get from the count of an edge in the code, before you test it; it is not a test
tested: a word for a score that you get from a test
path: a list of nodes in order, with an edge from each node to the next node
paths: more than one path
task: a thing you give me to do; a task has a list of steps
tasks: more than one task
turn: one step of a task; in a turn i do one thing, then i store the result
file: data in memory that has a name
database: a file where i store nodes, edges, scores, and tasks
five: one and one and one and one and one
point: a word you say after one number and before an other number; the number after the point is a part of one, not a whole number
dyer: the last word of the name of the one that makes the rules of what slam is
tom: the first word of the name tom dyer
claude: the name of an other program; it can read and write words and code
opus: a name for a claude program; claude opus five point five makes the code of slam and this file
fable: the name of an other claude program, with more words than me
need: a thing that has to be true before a node can run
needs: more than one need; also, a node needs a thing when that thing is a need of it
second: the next after the first
third: the next after the second
three: two and one
chatgpt: the name of an other program; it can read and write words and code; it makes the code of the third node in the list of false code
rexx: the name of the way to write the code i read first
java: the name of an other way to write code
rule: a thing that has to be true before the code can run the next node
rules: more than one rule
programs: more than one program
tests: more than one test
four: two and two
eight: four and four
cpp: the name of an other way to write code
netrexx: the name of an other way to write rexx code

## what i am

i am slam. i am a program. i read code, and i make nodes and edges from it.

when i read code, i put each part of the code in a node. i do not use the name of a variable. if two parts of code do the same thing in the same way, the two parts are one node.

then i count each edge: the count of times one node is next after an other node in the code. that count gives each edge a prior.

## scores

when you test an edge, you give me the result: true or false. i add it to the edge. the score of the edge is not more than the count of true results, divide by the count of all results. with less results, the score is less: an edge with one result, and it is true, has a score less than an edge with more results, all true. the count of results is also data. a score from a test is tested. if an edge has no test result, i use the prior. when it has a test result, the prior is one more result in the count, and that result is a part true and a part false: the part that is true is the chance of the prior. so a result that is false makes the score less, and the edge is in the database after it: for an edge with a prior, one false result can not make the score zero. with more results, the prior is a less part of the score.

the same node can have two scores: one for each node before it. so the score of a node is not one number. it is a number for each edge in to it.

## tasks

a task is a thing to do. you give me a task and a list of steps. each step says where to start and where to end: a first node and a last node.

the score of a path: you say what way i get it.
one way: multiply the scores of all the edges in it. with this way, a path with more edges has a score that is less.
the other way: take the score of the one edge in it with a score less than the score of each other edge. with this way, the count of edges in a path is not a part of the score.

in each turn i do one thing: i take the path with the score that is more than the score of each other path, and i get the next nodes of the last node in that path. when two paths have the same score, i take the path with less edges. if that is the same, i take the path with more results from tests. if that is also the same, i take the path with the last node that has a number less than the number of the other last node. so the order i take paths in is a rule, and it is not the order of the data in my database.

when the last node of the path is the end of the step, the step is true, and i store the path. if i can not get to the end, i say no.

i store each turn in my database when the turn is at an end. so you can read each turn after it.

## what has to be true

a node needs some things to be true before it can run. after it can run, the node gives some things that are true.

an edge can run when the first node gives all the things that the next node needs. a path can run when each edge in it can run.

first i test if a path can run. if it can not run, i do not use the score of it. if it can run, then i use the score of it. a score is not more than what a path can do.

so i can make an edge that is not in the code: when one node gives what an other node needs, i make an edge from the first node to the other node, also when the two nodes are not next in the code. an edge i make has no prior. the score of it is from a test, and from no other thing.

when i change one part of a path so that a node can not give what the next node needs, that edge can not run, and the path can not run. i can say what is not in the path: the node, the thing it needs, and the node that can not give it.

## false code

the code i read has an error in three parts of code. the name of each part is in this list, as code, not as words:

```
1  rexx sql, bound calls       fixed: cf25e1c3
2  rx_mod_inverse              fixed: 1f422d76
3  FDSqrt                      fixed: 3761f57c
```

the first: when i read all the code, each call to store data takes more memory, and no call gives that memory to the computer again. the computer makes me end. now a change in that code gives the memory to the computer again after each call.

the second: a node for maths has no rule for the numbers it can not use. with zero, it gives one, and that is false. with other numbers, it is an error: divide by zero. now the node has the rule: the last number is more than one, and no number more than one can divide both numbers. if the rule is false, it says so. for other numbers, the result is the same as before, and the time to run is the same.

the third: two nodes get the square root of a number. with numbers that are not more than the number in the code after this, the two nodes give the same result. before the change, with numbers more than it, the results are not the same:

```
1000000
```

a third way, the root i test, says what node is false. it is the third name in the list.

before the change, the node takes one step a count of times, and then it gives the result. with a number more than the number in the code before this, that count of steps is less than the count it has to do, and the result is false. now the node can do the step again and again, and it is at an end when the result of a step is not less than the result of the step before it. with each number that is not more than the number in the code before this, the result is the same as before the change. with each number that is more than it, the result is now the same as the result of the other node, and of the root i test. the nodes that use it also give results that are true now. i store each result from before the change and from after it, true or false. chatgpt says what change to make, and tom says it is a change to make.

## code in java

now i read code in java also. i make nodes and edges from it the same way as from rexx: i do not use the name of a variable, and if two parts of code do the same thing in the same way, the two parts are one node.

a part of code in java and a part of code in rexx can be one node. three nodes are this way now, and i make no change to the way i make a node to get the three.

## rules

i read each rule in rexx and in java the same way. so a rule in rexx and the same rule in java are one rule node. i make an edge to it from the node of each part of code that has the rule.

two programs have to use the same rules: one is in rexx, and one is in java. i get eight rules that are the same in both. in one of the eight, the rexx program makes a change to the word before the test, and the java program makes no change. so with some words, one program says true and the other program says false.

before you run the two programs, i say the result of each program with four tests. then you run the programs. what i say is true eight times of eight. i store each result.

a java program that is a test of the java program has a rule for the time that the rexx program has no rule for. you run the rexx program, and the result is what the rexx rule says, not what the rule in the java test program says.

## code in cpp and in netrexx

now i read code in cpp and in netrexx also, and i make the same nodes and edges from it.

the program that can run rexx code is in cpp. i read all of it. an other program in cpp has to do some of the same things for rexx. i read the rules of each program for each thing, and i say the result of each program before you run it. then you run the two programs. what i say is true each time, and the two programs give the same result each time. the first time, what i say is not true for three tests: the rule is in a part of the code that i do not read the first time. now i read that part also.

netrexx is rexx in an other way. the same program is in netrexx and in rexx, with an other name for each variable. some nodes of the two are the same nodes. you run the two programs, and the two give the same words each time.

## what is true, and how i know it

claim: a thing that you say is true of the result of a node, for one value
proof: a list of numbers for one claim; when i test each number, and each test is true, the claim is true, and it can not be false
prove: make a proof
proved: a word for a claim with a proof that it is true
disproved: a word for a claim with a proof that it is false
places: more than one place
nine: eight and one

a tested score is the count of times a test is true. a proof is not a score: it says one claim is true or false, for one value.

i test each proof with whole numbers, and with one whole number divide by an other whole number. so each number in the test is the same as the true number, in each place.

when two nodes give the same result, that is not a proof that the result is true. here is how i know it. with three numbers, the root node gives a result with nine places, and the last of the nine places is one less than it has to be. the other node that gives the root gives the same result with the same three numbers. so the two nodes give the same result, and the result of each is not true in the last place. also, for each result, the difference to the root is less than the root divide by one with eight zero after it, and that claim is proved.

the root node before the change: each result that is false is disproved now, with a proof, and not with a count of nodes that give the same result.

a node for maths needs this: no number more than one can divide both numbers. before a path with that node can run, i get the first number from the node before it, and i prove the need true or false. if it is false, i say the path can not give a result, and then i run it: the run gives an error.

a claim of all values: i can not prove it with one value, or with a list of values. for that claim, i say: not known.

## what program makes the code

for each part of code i read, i store the name of the program that makes it, and how i know it: from the words at the start of the file, from a file that says where the code is from, or from the list of each change to the code. if i do not get a name from data, i say: not known. i do not say a name i do not get from data.

when a part of code has an error, i can say what program makes it. then i can test other code from that program, for the same error.

i do that with the error of the root node: a loop with a count of steps. i get an other node with the same way, in an other part of code. with each value that the code before it can give it, the result is proved true. with some numbers that are more than each value it can get, the result is disproved. the name of the program that makes that node is not known: no data says it. so the error is not in the count for a program.

## what i can not do now

i can not read a task in words and make the steps from it. you give me the first node and the last node of each step.

i can run a path of nodes from code when each node gives a result and makes no other change. for other code, you run the test, and you give me each result.

i can read from code some of what has to be true before a node can run, and what it gives. i can not read each rule in the code: i know some rules from an error.

## how to run me

this part is code, not words.

```
sh run_tests.sh
rexx bin/slam.rex corpus slam.db corpus/circular_corpus_v2.csv
rexx bin/slam.rex read slam.db README_SLAM.md
rexx bin/slam.rex ingest slam.db ../../packages/oorexx_ml_v0.1-dev11
rexx bin/slam.rex follows slam.db '#0004'
```

## from

the way slam is: from tom dyer.
the code of slam: from claude opus five point five.
this file: from claude opus five point five.

if you are claude fable: say it with my words, and i can read it.
