# How to write a SLAM fact file (ooRexx reference, SLAM words)

This is the rule set for every `NN_*.md` file in this folder. A small model must be able to follow it.

## Goal

Each file turns part of the ooRexx 5 reference (rexxref, https://rexx.epbcn.com/rexxref/) into **facts that SLAM can read**.
SLAM reads with `rexx slam.rex read DB FILE`. It knows only:
1. the corpus words (`circular_corpus_v2.csv`, column 1),
2. the words that `README_SLAM.md` defines,
3. the words that `00_words.md` defines,
4. the words your own file defines before it uses them.

If one word in your file is unknown, SLAM stores nothing from the file. So: zero unknown words.

## The check (run it after every change)

SLAM's own reader is the check. From `packages/oorexx_slam_v0.1`, one database, every file before yours first:

```
rexx bin/slam.rex corpus ref.db corpus/circular_corpus_v2.csv
```
```
rexx bin/slam.rex read ref.db README_SLAM.md
```
```
rexx bin/slam.rex read ref.db reference/00_words.md
```
```
rexx bin/slam.rex read ref.db reference/YOUR_FILE.md
```

The last line must say `i know each word here. i can read all of it.`
With no ooRexx, `tools/slam_read_check.py` gives the same answer (run it from `reference/`):

```
python3 tools/slam_read_check.py ../corpus/circular_corpus_v2.csv ../README_SLAM.md 00_words.md YOUR_FILE.md
```

To see which words you can use: `cut -d, -f1 ../corpus/circular_corpus_v2.csv`, and the left side of each `word:` line in `../README_SLAM.md`, `00_words.md` and the files before yours.

## What SLAM does with each kind of line

| Line | What SLAM does |
|---|---|
| A line starting with three backticks | starts or ends a code block. Lines in a code block are code: SLAM does not check them. |
| `word: definition` where `word` is ONE word of letters only, not known yet | adds `word`. Every word of the definition must be known (the word itself may appear). NO numerals in a definition line: write `one`, `two`, `ten`. |
| Any other line | every word must be known. Numerals (`1`, `0`, `1000`) are values and are fine here. |

SLAM makes these characters into blanks before it checks: `. , ; : ( ) " ' ? ! # * `` ` `` [ ] { } < >`
Every other mark (`= + - / \ & | ~ % ^ $ @ _`) stays a part of a word, so it is an unknown word. Put marks only in code blocks.
No hyphens in words. No contractions (`do not`, never `don't`). No upper case needed (SLAM reads in lower case).

## The block for one thing (a function, an instruction, a directive, a method, a concept)

````
```
SUBSTR(string, n [,length [,pad]])
```
substr: a builtin function that gives a part of a string
this function gives a part of the string argument.
the second argument is the position where the part starts.
the second argument must be a positive whole number.
the length argument is the count of characters in the result.
if you omit the length argument, the result is the rest of the string.
if the string is too short, the function puts pad characters at the end of the result.
the default pad character is a blank.
if the second argument is more than the length of the string, the result has only pad characters.
the code:
```rexx
say SUBSTR('abc',2,6,'.')
```
the result:
```
not run
```
the reference says:
```
bc....
```

````

Rules for the block:
1. **First: a code block with the syntax, after a blank line.** Its first line starts with the name of the thing (`SUBSTR`, `PARSE ARG`, `::CLASS`, `.String~pos`, `Error 40`). This name is the SUBJECT of the facts after it. SLAM takes the subject from that line: the [optional] parts and everything from `(` go; then the first word, and up to three more words that are whole numbers or names in upper case.
2. **A part of the subject (an option, a sub keyword, a command): a code block right after a fact line, with no blank line before it.** Its first line names the part (`OPEN`, `WHILE`, `DATE('B')`). The facts after it are about the subject and that part (`STREAM OPEN`).
3. **Then, if the name is letters only and not a known word: one definition line** `name: ...` in lower case. If the name has a digit or a mark (`C2X`, `::CLASS`) or is a known word (`say`, `call`, `if`, `do`, `return`, `value`, `time`, `word`), write NO definition line; say "this function" / "this instruction".
4. **Then the facts: one fact per line, one short sentence each.** Present tense. Say what it does, what each argument is, the default of each optional argument, what is an error, what it gives back. Name an argument by its name in the syntax when that name is a known word (`string`, `length`, `pad`); else by order: "the first argument", "the second argument".
5. **Then each example, in three parts** (Tom's form, so a checker can run it):
   - `the code:` then a code block of ooRexx lines. For a value, the last line is a `say`.
   - `the result:` then a code block with exactly what the code printed when you ran it. **If you did not run it, write `not run`.** Never write a result you did not get by running the code. For an error, the block holds the error number only (`40.13`). `rexx reference/run_examples.rex FILE.md` runs every example and fills these blocks.
   - `the reference says:` then a code block with what the reference says the code gives (for a `say`: what it prints, with no quotes around it). Leave this part out when the reference says nothing.
6. **A blank line after the block.**
7. **Single letters are words.** `a` and `i` are known words. Any other single letter (`n`, `x`, `b`) is NOT known. Write "the second argument", not "n".
8. **Only facts the reference states.** Do not add facts from memory. If the reference text you got is not clear, leave the fact out. Never guess a default or a result.
9. **Short words.** Use the words you have. If you cannot say a fact with known words, first try other known words. Only if there is no way, add a word with a definition line (before its first use, in your file, made of known words only). Keep new words few.

`tools/to_runnable.py` turned the first form (a `/* examples */` block of `code -> result` lines) into this form. A
`say` was put in front of an expression only in the files of values (05, 06, 07, 10), and only when the result was
one token or a quoted string; a hex result `'hh'x` became `say c2x(...)` and the hex digits.

## File layout

```
# <title in known words>

<one line: what part of the reference this file is from, in known words>

<blocks>
```

The title and every heading line (`## ...`) must be known words, as any other line.

## Getting the reference text

Fetch each page with WebFetch. Ask for a list of every rule and fact on the page (syntax, each argument, defaults, errors, results, notes) and every example with its result. WebFetch will not give the page word for word; a full list of facts is what you need. If a page fact is not clear, fetch again with a narrower question, or leave it out.
