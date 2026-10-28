# the string class, and a class for a string you can change

these facts are from the rules of the oorexx language, the part about the string class and the part about the class after it.

## the string class

```
.String
```
an instance of the string class is a string value.
a string value can have any length and any characters.
the string class has the methods of the object class.
the string class inherits the method in the code after this from a mixin class.
```
compareTo
```

## class methods of the string class

```
.String~new(stringvalue)
```
you send this message to the string class, not to a string.
this method gives a new string object with the characters of the argument.

```
.String~alnum
```
alnum: a method of the string class that gives all the letters and digits
you send this message to the string class, not to a string.
this method gives the string in the code after this: the ten digits, then the letters in upper, then the letters in lower.
the result is the kind of characters with the name alnum.
```
0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
```

```
.String~alpha
```
alpha: a method of the string class that gives all the letters
you send this message to the string class, not to a string.
this method gives the string in the code after this: the letters in upper, then the letters in lower.
the result is the kind of characters with the name alpha.
```
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
```

```
.String~blank
```
you send this message to the string class, not to a string.
this method gives the string in the code after this.
the result is the kind of characters with the name blank.
```
'09 20'x
```

```
.String~cntrl
```
cntrl: a method of the string class that gives a string of characters that are not letters, digits, or marks
you send this message to the string class, not to a string.
this method gives the string in the code after this.
the result is the kind of characters with the name cntrl.
```
'00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 15 16 17 18 19 1A 1B 1C 1D 1E 1F 7F'x
```

```
.String~cr
```
cr: a method of the string class that gives the character with the value in the code after it
you send this message to the string class, not to a string.
this method gives a string of one character: the character with the value in the code after this.
```
'0d'x
```

```
.String~digit
```
you send this message to the string class, not to a string.
this method gives the string of the ten digits in order, in the code after this.
the result is the kind of characters with the name digit.
```
0123456789
```

```
.String~graph
```
graph: a method of the string class that gives each character that is a letter, a digit, or a mark
you send this message to the string class, not to a string.
this method gives the string in the code after this.
the result is the kind of characters with the name graph.
```
!"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~
```

```
.String~lower
```
you send this message to the string class, not to a string.
this method gives the letters in lower, in the code after this.
the result is the kind of characters with the name lower.
```
abcdefghijklmnopqrstuvwxyz
```

```
.String~nl
```
nl: a method of the string class that gives the character with the value in the code after it
you send this message to the string class, not to a string.
this method gives a string of one character: the character with the value in the code after this.
```
'0a'x
```

```
.String~null
```
you send this message to the string class, not to a string.
this method gives a string of one character: the character with the value in the code after this.
the result is not an empty string.
```
'00'x
```

```
.String~print
```
print: a method of the string class that gives each letter, digit, and mark, and the blank
you send this message to the string class, not to a string.
this method gives the string of the graph method with a blank before it.
the result is the kind of characters with the name print.

```
.String~punct
```
punct: a method of the string class that gives each mark that is not a letter and not a digit
you send this message to the string class, not to a string.
this method gives the string in the code after this.
the result is the kind of characters with the name punct.
```
!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
```

```
.String~space
```
space: a method that gives blank characters; also a method that changes the blanks between words
you send this message to the string class, not to a string.
this method gives the string in the code after this.
the result is the kind of characters with the name space.
```
'09 0A 0B 0C 0D 20'x
```

```
.String~tab
```
tab: a method of the string class that gives the character with the value in the code after it
you send this message to the string class, not to a string.
this method gives a string of one character: the character with the value in the code after this.
```
'09'x
```

```
.String~upper
```
you send this message to the string class, not to a string.
this method gives the letters in upper, in the code after this.
the result is the kind of characters with the name upper.
```
ABCDEFGHIJKLMNOPQRSTUVWXYZ
```

```
.String~xdigit
```
xdigit: a method of the string class that gives the hexadecimal digits
you send this message to the string class, not to a string.
this method gives the string in the code after this: the ten digits, then six letters in upper, then the same six letters in lower.
the result is the kind of characters with the name xdigit.
```
0123456789ABCDEFabcdef
```

## operator methods of the string class

```
.String~+(argument)
.String~-(argument)
.String~*(argument)
.String~/(argument)
.String~%(argument)
.String~//(argument)
.String~**(argument)
.String~-
.String~+
```
these are the maths methods of the string class.
each method gives the result of its maths on the receiver.
the receiver and the argument must be numbers.
the method on line 1 adds the argument to the receiver.
the method on line 2 gives the receiver subtract the argument.
the method on line 3 gives the receiver multiply by the argument.
the method on line 4 gives the receiver divide by the argument.
the method on line 5 does a divide and gives only the integer part of the result.
the method on line 6 does a divide and gives the remainder.
the result of the method on line 6 can be negative.
the method on line 7 gives the receiver to the power of the argument; the argument must be a whole number.
the method on line 8 has no argument; it gives zero subtract the receiver.
the method on line 9 has no argument; it gives zero add the receiver.
if a result has an exponent, the result may be rounded.
the code:
```rexx
Say 5+5
```
the result:
```
10
```
the reference says:
```
10
```

the code:
```rexx
Say 8-5
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
Say 5*2
```
the result:
```
10
```
the reference says:
```
10
```

the code:
```rexx
Say 6/2
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
Say 9//4
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say 9%4
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
Say 2**3
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
Say +5
```
the result:
```
5
```
the reference says:
```
5
```

the code:
```rexx
Say -5
```
the result:
```
-5
```
the reference says:
```
-5
```

```
.String~=(argument)
.String~\=(argument)
.String~><(argument)
.String~<>(argument)
.String~>(argument)
.String~<(argument)
.String~>=(argument)
.String~\<(argument)
.String~<=(argument)
.String~\>(argument)
```
strict: a strict compare uses each character as it is; it does not compare values as numbers and it does not use pad
these are the compare methods of the string class that are not strict.
each method gives true or false.
the method on line 1 gives true if the receiver and the argument are equal, as numbers or with pad blanks.
the method on line 1 gives false if the argument is nil.
the methods on lines 2, 3, and 4 give true if the two values are not equal.
the methods on lines 2, 3, and 4 give true if the argument is nil.
the method on line 5 gives true if the receiver is more than the argument.
the method on line 6 gives true if the receiver is less than the argument.
the method on line 7 gives true if the receiver is more than or equal to the argument.
the method on line 8 gives true if the receiver is not less than the argument.
the method on line 9 gives true if the receiver is less than or equal to the argument.
the method on line 10 gives true if the receiver is not more than the argument.
the methods on lines 5 to 10 give false if the argument is nil.
if the receiver and the argument are both numbers, these methods compare them as numbers.
if not, these methods compare them as strings: they ignore blanks at the left and at the right, and put blanks at the right of the short string as pad.
a compare of characters is not caseless.
the code:
```rexx
5=5
```
the result:
```
31.2
```
the reference says:
```
1
```

the code:
```rexx
say 42\=41
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say 42><41
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say 42<>41
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say 13>12
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say 12<13
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say 13>=12
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say 12\<13
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say 12<=13
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say 12\>13
```
the result:
```
1
```
the reference says:
```
1
```

```
.String~==(argument)
.String~\==(argument)
.String~>>(argument)
.String~<<(argument)
.String~>>=(argument)
.String~\<<(argument)
.String~<<=(argument)
.String~\>>(argument)
```
these are the strict compare methods of the string class.
each method gives true or false.
the method on line 1 gives true if the receiver and the argument are the same string.
the method on line 1 gives false if the argument is nil.
the method on line 2 gives true if the receiver and the argument are not the same string.
the method on line 2 gives true if the argument is nil.
the method on line 3 gives true if the receiver is more than the argument.
the method on line 4 gives true if the receiver is less than the argument.
the method on line 5 gives true if the receiver is more than or equal to the argument.
the method on line 6 gives true if the receiver is not less than the argument.
the method on line 7 gives true if the receiver is less than or equal to the argument.
the method on line 8 gives true if the receiver is not more than the argument.
the methods on lines 3 to 8 give false if the argument is nil.
a strict method compares each character, from left to right, and uses no pad.
a string that is the left part of an other string with more characters is less than that string.
a strict method does not compare the values as numbers.
the methods on lines 1 and 2 need the same characters and the same length.
a compare of characters is not caseless.
the code:
```rexx
say "space"=="space"
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "space"\==" space"
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "space">>" space"
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say " space"<<"space"
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "space">>=" space"
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "space"\<<" space"
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say " space"<<="space"
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say " space"\>>"space"
```
the result:
```
1
```
the reference says:
```
1
```

each compare method needs the receiver and the argument to be strings.
if the argument is not a string, a compare method uses the string value of it.
a string is never equal to nil, also when the string has the same characters as the string value of nil.

```
.String~""(argument)
.String~||(argument)
.String~" "(argument)
```
these are the methods of the string class that put the argument after the receiver.
each method gives the receiver, then the argument, as one string.
the method on line 1 is the null string: the language uses it for two values next to each other with no operator between them.
the methods on lines 1 and 2 put no blank between the two values.
the method on line 3 puts one blank between the two values.
the code:
```rexx
f = "abc"
Say f"def"
```
the result:
```
abcdef
```
the reference says:
```
abcdef
```

the code:
```rexx
f = "abc"  /* setup from the example before */
Say f || "def"
```
the result:
```
abcdef
```
the reference says:
```
abcdef
```

the code:
```rexx
f = "abc"  /* setup from the example before */
Say f "def"
```
the result:
```
abc def
```
the reference says:
```
abc def
```

```
.String~&(argument)
.String~|(argument)
.String~&&(argument)
.String~\
```
these are the boolean methods of the string class.
each method gives true or false.
the receiver and the argument are strings with the value 1 or 0.
the method on line 1 gives 1 if both values are true.
the method on line 2 gives 1 if one value or both values are true.
the method on line 3 gives 1 if one value is true, but not both values.
the method on line 4 has no argument; it changes 1 to 0, and 0 to 1.
the code:
```rexx
Say 1&0
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say 1|0
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say 1&&0
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say \1
```
the result:
```
0
```
the reference says:
```
0
```

## instance methods of the string class

```
.String~[](n [,length])
```
this method gives the character at the position of the first argument in the receiver.
if the first argument is more than the length of the receiver, the result is a null string.
if you give the length argument, the result is the part of the receiver that starts at the position of the first argument and has that length.
with the length argument, this method puts no pad in the result.
the first argument must be a positive whole number.
the length argument must be zero or a positive whole number.
the code:
```rexx
Say "abc"[2]
```
the result:
```
b
```
the reference says:
```
b
```

the code:
```rexx
Say "abc"[2,4]
```
the result:
```
bc
```
the reference says:
```
bc
```

```
.String~?(argument1, argument2)
```
this method gives the first argument if the receiver is true.
this method gives the second argument if the receiver is false.
the code:
```rexx
do apples = 0 to 2
  say apples (apples = 1)~?("apple", "apples")
end
```
the result:
```
0 apples
1 apple
2 apples
```
the reference says:
```
0 apples
```

```
.String~abbrev(info [,length])
```
abbrev: a method of the string class that tests if a string is the left part of an other string
this method gives 1 if the first argument is equal to the left characters of the receiver, and the length of the first argument is not less than the length argument.
if not, this method gives 0.
the length argument must be zero or a positive whole number.
the default length is the count of characters in the first argument.
a null first argument gives 1 when the length argument is 0 or omitted.
so a program can use a null string to get a default keyword.
the code:
```rexx
Say "Print"~abbrev("Pri")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "PRINT"~abbrev("Pri")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "PRINT"~abbrev("PRI",4)
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "PRINT"~abbrev("PRY")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "PRINT"~abbrev("")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "PRINT"~abbrev("",1)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~abs
```
this method gives the absolute value of the receiver.
the result has no sign.
the instruction in the code after this says the way of the result.
```
NUMERIC
```
the code:
```rexx
say 12.3~abs
```
the result:
```
12.3
```
the reference says:
```
12.3
```

the code:
```rexx
say "-0.307"~abs
```
the result:
```
0.307
```
the reference says:
```
0.307
```

```
.String~append(string)
```
append: a method that puts a string at the end of an other string
this method gives a string: the receiver, then the argument.

```
.String~b2x
```
this method gives the hexadecimal value of the receiver.
the receiver must have only binary digits.
the receiver can have any length.
the receiver can have blanks between parts of four digits, but not at the left or at the right; this method ignores them.
the letters in the result are in upper.
the result has no blanks.
if the receiver is a null string, the result is a null string.
if the count of digits is not four, eight, or more times four, this method first adds one, two, or three zero digits at the left.
the code:
```rexx
Say "11000011"~b2x
```
the result:
```
C3
```
the reference says:
```
C3
```

the code:
```rexx
Say "10111"~b2x
```
the result:
```
17
```
the reference says:
```
17
```

the code:
```rexx
Say "101"~b2x
```
the result:
```
5
```
the reference says:
```
5
```

the code:
```rexx
Say "1 1111 0000"~b2x
```
the result:
```
1F0
```
the reference says:
```
1F0
```

the code:
```rexx
say "10111"~b2x~x2d
```
the result:
```
23
```
the reference says:
```
23
```

```
.String~compare(string [,pad])
```
this method compares the receiver and the argument string.
this method gives 0 if the two strings are the same.
if not, this method gives the position of the first character that is not the same.
this method puts pad characters at the right of the short string if it must.
the default pad character is a blank.
the code:
```rexx
Say "abc"~compare("abc")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "abc"~compare("ak")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
Say "ab "~compare("ab")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "ab "~compare("ab"," ")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "ab "~compare("ab","x")
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
Say "ab-- "~compare("ab","-")
```
the result:
```
5
```
the reference says:
```
5
```

```
.String~compareTo(string [,n] [,length])
```
this method compares the receiver and the argument string, to put them in order.
this method gives 0 if the two strings are equal.
this method gives 1 if the receiver is more.
this method gives -1 if the argument string is more.
the compare starts at the character at the position of the second argument, and uses the count of characters of the length argument, in both strings.
if you omit the second argument, the compare starts at the first character.
the second argument must be a positive whole number.
if you omit the length argument, the compare goes to the end of the receiver.
the length argument must be zero or a positive whole number.
the code:
```rexx
Say "abc"~compareTo("abc")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "b"~compareTo("a")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "a"~compareTo("b")
```
the result:
```
-1
```
the reference says:
```
-1
```

the code:
```rexx
Say "abc"~compareTo("aBc")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "aBc"~compareTo("abc")
```
the result:
```
-1
```
the reference says:
```
-1
```

the code:
```rexx
Say "000abc000"~compareTo("111abc111", 4, 3)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~contains(other [,start [,length]])
```
contains: a method that tests if a string is a part of an other string
this method gives true if the first argument is a part of the receiver.
this method gives false if the first argument is a null string, or is not a part of the receiver.
by default, this method starts at the first character and goes to the end of the receiver.
the start argument is the position where this method starts.
the start argument must be a positive whole number.
the length argument is the count of characters, from the start, where this method can find the first argument.
the length argument must be zero or a positive whole number.
the code:
```rexx
say "-abcdef-"~contains("ef")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "-abcdef-"~contains("-", 2, 6)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~containsWord(phrase [,start])
```
this method gives true if the words of the first argument are in the receiver.
this method gives false if the first argument has no words, or if its words are not in the receiver.
more than one blank between words, in the first argument or in the receiver, is the same as one blank for this method.
if not, the words must be the same.
by default, this method starts at the first word of the receiver.
the start argument is the number of the word where this method starts.
the start argument must be a positive whole number.
this method gives false only when the method in the code after this gives 0.
```
wordPos
```
the code:
```rexx
good = "Now is the time for all good men"
say good~containsWord("the")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~containsWord("The")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~containsWord("is the")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~containsWord("is   the ")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~containsWord("is time")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~containsWord("time")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~containsWord("time", 5)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~copies(n)
```
copies: a method that gives a string many times, one after the other
this method gives a string of the receiver, the count of times of the argument, with no blanks between them.
the argument must be zero or a positive whole number.
with zero, the result is an empty string.
the code:
```rexx
Say "abc"~copies(3)
```
the result:
```
abcabcabc
```
the reference says:
```
abcabcabc
```

the code:
```rexx
Say "abc"~copies(0)
```
the result:
```

```
the reference says:
```

```

```
.String~countStr(needle)
```
this method gives the count of times the argument string is in the receiver.
this method counts a part only when it has no characters of an other part it counts.
the code:
```rexx
Say "101101"~countStr("1")
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
Say "J0KKK0"~CountStr("KK")
```
the result:
```
1
```
the reference says:
```
1
```

```
.String~modulo(n)
```
modulo: a method that gives the remainder of a divide; the result is never negative
this method gives the remainder when you divide the receiver by the argument.
the receiver must be a whole number.
the argument must be a positive whole number.
the result is not less than zero and is less than the argument.
if the receiver and the argument are both zero or positive whole numbers, the result is the same as the remainder operator in the code after this.
```
//
```
the code:
```rexx
Say 10~modulo(3)
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say (-10)~modulo(3)
```
the result:
```
2
```
the reference says:
```
2
```

```
.String~overlay(new [,n [,length [,pad]]])
```
overlay: a method that puts a string on a part of an other string, in the place of the characters there
this method gives the receiver with the first argument in the place of the characters from the position of the second argument.
first, this method makes the first argument have the length of the length argument, with pad characters or by a cut.
the new part can go after the end of the receiver.
the default of the second argument is 1.
the second argument must be a positive whole number.
the default length is the length of the first argument.
the length argument must be zero or a positive whole number.
if the second argument is more than the length of the receiver, this method puts pad characters before the new part.
the default pad character is a blank.
the code:
```rexx
say "abcdef"~overlay(" ",3)
```
the result:
```
ab def
```
the reference says:
```
ab def
```

the code:
```rexx
say "abcdef"~overlay(".",3,2)
```
the result:
```
ab. ef
```
the reference says:
```
ab. ef
```

the code:
```rexx
say "abcd"~overlay("qq")
```
the result:
```
qqcd
```
the reference says:
```
qqcd
```

the code:
```rexx
say "abcd"~overlay("qq",4)
```
the result:
```
abcqq
```
the reference says:
```
abcqq
```

the code:
```rexx
say "abc"~overlay("123",5,6,"+")
```
the result:
```
abc+123+++
```
the reference says:
```
abc+123+++
```

```
.String~pos(needle [,start [,length]])
```
pos: a method that gives the position of a string in an other string
this method gives the position of the first argument in the receiver.
this method gives 0 if the first argument is a null string.
this method gives 0 if the first argument is not in the receiver.
this method gives 0 if the start argument is more than the length of the receiver.
the default start is 1, and by default this method goes to the end of the receiver.
the start argument is the position where this method starts.
the start argument must be a positive whole number.
the length argument is the count of characters, from the start, where this method can find the first argument.
the length argument must be zero or a positive whole number.
the code:
```rexx
say "Saturday"~pos("day")
```
the result:
```
6
```
the reference says:
```
6
```

the code:
```rexx
say "abc def ghi"~pos("x")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "abc def ghi"~pos(" ")
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say "abc def ghi"~pos(" ",5)
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
say "abc def ghi"~pos(" ",5,3)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~replaceAt(new, n [,length [,pad]])
```
this method gives the receiver with the first argument in the place of some characters.
the characters it takes away start at the position of the second argument, and the count of them is the length argument.
this method does not change the receiver.
the part it takes away can go after the end of the receiver.
the second argument must be a positive whole number.
the length argument must be zero or a positive whole number.
the default length is the length of the first argument.
if the second argument is more than the length of the receiver, this method puts pad characters before the new part.
the default pad character is a blank.
the code:
```rexx
say "abcdef"~replaceAt(" ",3, 1)
```
the result:
```
ab def
```
the reference says:
```
ab def
```

the code:
```rexx
say "abcdef"~replaceAt(" ",3, 3)
```
the result:
```
ab f
```
the reference says:
```
ab f
```

the code:
```rexx
say "abc"~replaceAt("123",5,6,"+")
```
the result:
```
abc+123
```
the reference says:
```
abc+123
```

```
.String~reverse
```
reverse: a method that gives a string with its characters in the other order
this method gives the receiver with its characters in the other order: the last character first.
the code:
```rexx
say "ABc."~reverse
```
the result:
```
.cBA
```
the reference says:
```
.cBA
```

the code:
```rexx
say "XYZ "~reverse
```
the result:
```
 ZYX
```
the reference says:
```
 ZYX
```

```
.String~right(length [,pad])
```
this method gives a string of the count of characters of the length argument: the right characters of the receiver.
if the receiver is short, this method puts pad characters at the left.
if the length of the receiver is more than the length argument, this method takes away characters at the left.
the length argument must be zero or a positive whole number.
the default pad character is a blank.
the code:
```rexx
say "abc  d"~right(8)
```
the result:
```
  abc  d
```
the reference says:
```
  abc  d
```

the code:
```rexx
say "abc def"~right(5)
```
the result:
```
c def
```
the reference says:
```
c def
```

the code:
```rexx
say "12"~right(5,"0")
```
the result:
```
00012
```
the reference says:
```
00012
```

```
.String~bitAnd([string] [,pad])
```
this method gives a string: it does the boolean operator in the code after this on each bit of the receiver and the bit at the same place in the argument string.
```
&
```
this method uses the bytes of the two strings as they are in memory.
the default argument string is the null string.
the length of the result is the length of the string with more characters.
if you omit the pad argument, this method stops at the end of the short string, then puts the rest of the other string at the end of the result.
if you give the pad argument, this method first puts pad characters at the right of the short string.
the code:
```rexx
say c2x("12"x~bitAnd)
```
the result:
```
12
```
the reference says:
```
12
```

the code:
```rexx
say c2x("73"x~bitAnd("27"x))
```
the result:
```
23
```
the reference says:
```
23
```

the code:
```rexx
say c2x("13"x~bitAnd("5555"x))
```
the result:
```
1155
```
the reference says:
```
1155
```

the code:
```rexx
say c2x("13"x~bitAnd("5555"x,"74"x))
```
the result:
```
1154
```
the reference says:
```
1154
```

the code:
```rexx
Say "pQrS"~bitAnd(,"DF"x)  /* ASCII   */
```
the result:
```
PQRS
```
the reference says:
```
PQRS
```

```
.String~bitOr([string] [,pad])
```
this method gives a string: it does the boolean operator in the code after this on each bit of the receiver and the bit at the same place in the argument string.
```
|
```
this method uses the bytes of the two strings as they are in memory.
the default argument string is the null string.
the length of the result is the length of the string with more characters.
if you omit the pad argument, this method stops at the end of the short string, then puts the rest of the other string at the end of the result.
if you give the pad argument, this method first puts pad characters at the right of the short string.
the code:
```rexx
say c2x("12"x~bitOr)
```
the result:
```
12
```
the reference says:
```
12
```

the code:
```rexx
say c2x("15"x~bitOr("24"x))
```
the result:
```
35
```
the reference says:
```
35
```

the code:
```rexx
say c2x("15"x~bitOr("2456"x))
```
the result:
```
3556
```
the reference says:
```
3556
```

the code:
```rexx
say c2x("15"x~bitOr("2456"x,"F0"x))
```
the result:
```
35F6
```
the reference says:
```
35F6
```

the code:
```rexx
say c2x("1111"x~bitOr(,"4D"x))
```
the result:
```
5D5D
```
the reference says:
```
5D5D
```

the code:
```rexx
Say "pQrS"~bitOr(,"20"x)  /* ASCII   */
```
the result:
```
pqrs
```
the reference says:
```
pqrs
```

```
.String~bitXor([string] [,pad])
```
this method gives a string: it does the boolean operator in the code after this on each bit of the receiver and the bit at the same place in the argument string.
```
&&
```
this method uses the bytes of the two strings as they are in memory.
the default argument string is the null string.
the length of the result is the length of the string with more characters.
if you omit the pad argument, this method stops at the end of the short string, then puts the rest of the other string at the end of the result.
if you give the pad argument, this method first puts pad characters at the right of the short string.
the code:
```rexx
say c2x("12"x~bitXor)
```
the result:
```
12
```
the reference says:
```
12
```

the code:
```rexx
say c2x("12"x~bitXor("22"x))
```
the result:
```
30
```
the reference says:
```
30
```

the code:
```rexx
say c2x("1211"x~bitXor("22"x))
```
the result:
```
3011
```
the reference says:
```
3011
```

the code:
```rexx
say c2x("1111"x~bitXor("444444"x))
```
the result:
```
555544
```
the reference says:
```
555544
```

the code:
```rexx
say c2x("1111"x~bitXor("444444"x,"40"x))
```
the result:
```
555504
```
the reference says:
```
555504
```

the code:
```rexx
say c2x("1111"x~bitXor(,"4D"x))
```
the result:
```
5C5C
```
the reference says:
```
5C5C
```

the code:
```rexx
say c2x("C711"x~bitXor("222222"x," "))  /* ASCII  */
```
the result:
```
E53302
```
the reference says:
```
E53302
```

```
.String~c2d([n])
```
this method gives the decimal value of the bits of the receiver.
the result must be a whole number with not more digits than the precision; if not, it is an error.
the code after this says the precision.
```
NUMERIC DIGITS
```
if you omit the argument, the receiver is a binary number with no sign.
if you give the argument, the receiver is a number in that count of characters, and it can be negative.
if the left bit is 0, the number is positive; if the left bit is 1, the number is negative.
if you give the argument, this method puts characters with the value in the code after this at the left of a short receiver, or takes away characters at the left of a receiver with more characters.
```
'00'x
receiving_string~right(n,'00'x)
```
this is the same as the code on line 2 in the code before.
if the argument is 0, the result is 0.
if the receiver is a null string, the result is 0.
the code:
```rexx
Say "09"X~c2d
```
the result:
```
9
```
the reference says:
```
9
```

the code:
```rexx
Say "81"X~c2d
```
the result:
```
129
```
the reference says:
```
129
```

the code:
```rexx
Say "FF81"X~c2d
```
the result:
```
65409
```
the reference says:
```
65409
```

the code:
```rexx
Say ""~c2d
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "a"~c2d  /*  ASCII   */
```
the result:
```
97
```
the reference says:
```
97
```

the code:
```rexx
Say "81"X~c2d(1)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
Say "81"X~c2d(2)
```
the result:
```
129
```
the reference says:
```
129
```

the code:
```rexx
Say "FF81"X~c2d(2)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
Say "FF81"X~c2d(1)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
Say "FF7F"X~c2d(1)
```
the result:
```
127
```
the reference says:
```
127
```

the code:
```rexx
Say "F081"X~c2d(2)
```
the result:
```
-3967
```
the reference says:
```
-3967
```

the code:
```rexx
Say "F081"X~c2d(1)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
Say "0031"X~c2d(0)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~c2x
```
this method gives the hexadecimal value of the receiver, as a string of characters.
the result has two times the count of bytes of the receiver.
the letters in the result are in upper.
the result has no blanks.
the receiver can have any length.
if the receiver is a null string, the result is a null string.
the code:
```rexx
Say "0123"X~c2x  /* "30313233"X     in ASCII */
```
the result:
```
0123
```
the reference says:
```
0123
```

the code:
```rexx
Say "ZD8"~c2x  /* "354134343338"X in ASCII */
```
the result:
```
5A4438
```
the reference says:
```
5A4438
```

```
.String~caselessAbbrev(info [,length])
```
this method gives 1 if the first argument is equal to the left characters of the receiver, and the length of the first argument is not less than the length argument.
if not, this method gives 0.
the compare is caseless.
the length argument must be zero or a positive whole number.
the default length is the count of characters in the first argument.
a null first argument gives 1 when the length argument is 0 or omitted.
so a program can use a null string to get a default keyword.
the code:
```rexx
Say "Print"~caselessAbbrev("Pri")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "PRINT"~caselessAbbrev("Pri")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "PRINT"~caselessAbbrev("PRI",4)
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "PRINT"~caselessAbbrev("PRY")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "PRINT"~caselessAbbrev("")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "PRINT"~caselessAbbrev("",1)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~d2c([n])
```
this method changes the receiver, a decimal number, to characters, and gives the string of them.
if you omit the argument, the length of the result is the length it needs.
if you omit the argument, the receiver must be zero or a positive whole number.
if you omit the argument, the result has no characters with the value in the code after this at the left.
```
'00'x
```
if you give the argument, the result has that count of characters, with blanks at the left as pad if it must.
the argument must be zero or a positive whole number.
the receiver must not have more digits than the precision.
the code after this says the precision.
```
NUMERIC DIGITS
```
the code:
```rexx
say "65"~d2c  /* "41"x is an ASCII "A"    */
```
the result:
```
A
```
the reference says:
```
A
```

the code:
```rexx
say "65"~d2c(1)
```
the result:
```
A
```
the reference says:
```
A
```

the code:
```rexx
say c2x("65"~d2c(2))
```
the result:
```
0041
```
the reference says:
```
0041
```

the code:
```rexx
say c2x("65"~d2c(5))
```
the result:
```
0000000041
```
the reference says:
```
0000000041
```

the code:
```rexx
say "109"~d2c  /* "6D"x  is an ASCII "m"   */
```
the result:
```
m
```
the reference says:
```
m
```

the code:
```rexx
say c2x("-109"~d2c(1))  /* "93"x  is an ASCII "ô"   */
```
the result:
```
93
```
the reference says:
```
93
```

the code:
```rexx
say c2x("76"~d2c(2))  /* "4C"x  is an ASCII " L"  */
```
the result:
```
004C
```
the reference says:
```
004C
```

the code:
```rexx
say c2x("-180"~d2c(2))
```
the result:
```
FF4C
```
the reference says:
```
FF4C
```

```
.String~d2x([n])
```
this method changes the receiver, a decimal number, to hexadecimal, and gives the string of it.
the letters in the result are in upper.
the result has no blanks.
the receiver must not have more digits than the precision.
the code after this says the precision.
```
NUMERIC DIGITS
```
if you give the argument, it is the count of characters in the result.
if the number has more characters than the argument, this method takes away characters at the left.
the argument must be zero or a positive whole number.
if you omit the argument, the receiver must be zero or a positive whole number.
if you omit the argument, the result has no zero digits at the left.
the code:
```rexx
say "9"~d2x
```
the result:
```
9
```
the reference says:
```
9
```

the code:
```rexx
say "129"~d2x
```
the result:
```
81
```
the reference says:
```
81
```

the code:
```rexx
say "129"~d2x(1)
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "129"~d2x(2)
```
the result:
```
81
```
the reference says:
```
81
```

the code:
```rexx
say "129"~d2x(4)
```
the result:
```
0081
```
the reference says:
```
0081
```

the code:
```rexx
say "257"~d2x(2)
```
the result:
```
01
```
the reference says:
```
01
```

the code:
```rexx
say "-127"~d2x(2)
```
the result:
```
81
```
the reference says:
```
81
```

the code:
```rexx
say "-127"~d2x(4)
```
the result:
```
FF81
```
the reference says:
```
FF81
```

the code:
```rexx
say "12"~d2x(0)
```
the result:
```

```
the reference says:
```

```

```
.String~dataType([type])
```
this method tests what kind of string the receiver is.
if you omit the argument, this method gives the first string in the code after this if the receiver is a rexx number that you can add to 0 with no error; if not, it gives the second string.
```
NUM
CHAR
```
if you give the argument, this method gives true if the receiver is of that kind, and false if not.
a null receiver gives false for each kind, but true for the kind on line 2 and the kind on line 12 in the code after this.
this method uses only the first letter of the argument and ignores the other characters.
this method tests what the characters are, not how the computer stores them.
the code after this is the list of each kind you can give.
```
A   Alphanumeric
B   Binary
I   Internal whole number
L   Lowercase
M   Mixed case
N   Number
O   lOgical
S   Symbol
U   Uppercase
V   Variable
W   Whole number
X   heXadecimal
9   9Digits
```
the kind on line 1 is true if the receiver has only letters and digits.
the kind on line 2 is true if the receiver has only the digits 0 and 1, and blanks between parts of four digits.
the kind on line 3 is true if the receiver is a whole number that the builtin functions can use.
the kind on line 4 is true if the receiver has only letters in lower.
the kind on line 5 is true if the receiver has only letters, in upper or in lower.
the kind on line 6 is true if this method with no argument gives the first string in the code before.
the kind on line 7 is true if the receiver is 0 or 1.
the kind on line 8 is true if the receiver is a symbol; letters in upper and in lower can both be in it.
the kind on line 9 is true if the receiver has only letters in upper.
the kind on line 10 is true if the receiver can be at the left of an assignment with no error.
the kind on line 11 is true if the receiver is a whole number with the precision now in use.
the kind on line 12 is true if the receiver has only hexadecimal digits, in upper or in lower, and blanks between parts of two digits.
the kind on line 13 is true if the kind on line 11 is true when the precision is 9.
the code:
```rexx
Say " 12 "~dataType
```
the result:
```
NUM
```
the reference says:
```
NUM
```

the code:
```rexx
Say ""~dataType
```
the result:
```
CHAR
```
the reference says:
```
CHAR
```

the code:
```rexx
Say "123*"~dataType
```
the result:
```
CHAR
```
the reference says:
```
CHAR
```

the code:
```rexx
Say "12.3"~dataType("N")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "12.3"~dataType("W")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "Fred"~dataType("M")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say ""~dataType("M")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "Fred"~dataType("L")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "?20K"~dataType("s")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "BCd3"~dataType("X")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "BC d3"~dataType("X")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "1"~dataType("O")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "11"~dataType("O")
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~decodeBase64
```
this method gives a new string: the string that the receiver says in the way to write strings in the code after this.
```
base64
```
if the receiver is not a string in that way, it is an error.
the code:
```rexx
Say "YWJjZGVm"~decodeBase64
```
the result:
```
abcdef
```
the reference says:
```
abcdef
```

```
.String~delStr([n] [,length])
```
this method gives the receiver without a part.
the part starts at the position of the first argument and has the length of the length argument.
the default of the first argument is 1.
if you omit the length argument, or it is more than the count of characters to the end, this method takes away all the characters from that position to the end.
the length argument must be zero or a positive whole number.
the first argument must be a positive whole number.
if the first argument is more than the length of the receiver, this method gives the receiver with no change.
the code:
```rexx
Say "abcd"~delStr(3)
```
the result:
```
ab
```
the reference says:
```
ab
```

the code:
```rexx
Say "abcde"~delStr(3,2)
```
the result:
```
abe
```
the reference says:
```
abe
```

the code:
```rexx
Say "abcde"~delStr(6)
```
the result:
```
abcde
```
the reference says:
```
abcde
```

```
.String~delWord(n [,length])
```
this method gives the receiver without some words.
the words it takes away start at the word with the number of the first argument, and the count of them is the length argument.
if you omit the length argument, or it is more than the count of words to the end, this method takes away all the words from that word to the end.
the length argument must be zero or a positive whole number.
the first argument must be a positive whole number.
if the first argument is more than the count of words in the receiver, this method gives the receiver with no change.
this method also takes away the blanks after the last word it takes away, but not the blanks before the first word it takes away.
the code:
```rexx
Say "Now is the  time"~delWord(2,2)
```
the result:
```
Now time
```
the reference says:
```
Now time
```

the code:
```rexx
Say "Now is the time "~delWord(3)
```
the result:
```
Now is 
```
the reference says:
```
Now is 
```

the code:
```rexx
Say "Now is the  time"~delWord(5)
```
the result:
```
Now is the  time
```
the reference says:
```
Now is the  time
```

the code:
```rexx
Say "Now is   the time"~delWord(3,1)
```
the result:
```
Now is   time
```
the reference says:
```
Now is   time
```

```
.String~round
```
this method gives the integer that is next to the value of the receiver.
if the value is in the middle of two integers, the result is the integer with the absolute value that is more.
first this method makes the receiver a number with the rexx rules, the same as the code after this.
```
receiving_string+0
```
the result never has an exponent.
if the result has no digits that are not zero, it has no sign.
the code:
```rexx
say 2~round
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say '-2'~round
```
the result:
```
-2
```
the reference says:
```
-2
```

the code:
```rexx
say 2.4~round
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say '-2.4'~round
```
the result:
```
-2
```
the reference says:
```
-2
```

the code:
```rexx
say 2.5~round
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
say '-2.5'~round
```
the result:
```
-3
```
the reference says:
```
-3
```

the code:
```rexx
say '-0.1'~round
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~sign
```
this method gives a number that says the sign of the receiver, a number.
first this method makes the receiver rounded with the rexx rules, the same as the code after this.
```
receiving_string+0
```
the result is -1 if that value is less than 0, 0 if it is 0, and 1 if it is more than 0.
the code:
```rexx
say "12.3"~sign
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say " -0.307"~sign
```
the result:
```
-1
```
the reference says:
```
-1
```

the code:
```rexx
say 0.0~sign
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~space([n] [,pad])
```
this method gives the receiver with the count of pad characters of the first argument between each two words.
the first argument must be zero or a positive whole number.
the default of the first argument is 1.
if the first argument is 0, this method takes away all blanks.
this method always takes away the blanks at the left and at the right.
the pad argument is the character this method puts between words.
the default pad character is a blank.
the code:
```rexx
say "abc  def  "~space
```
the result:
```
abc def
```
the reference says:
```
abc def
```

the code:
```rexx
say "  abc def"~space(3)
```
the result:
```
abc   def
```
the reference says:
```
abc   def
```

the code:
```rexx
say "abc  def  "~space(1)
```
the result:
```
abc def
```
the reference says:
```
abc def
```

the code:
```rexx
say "abc  def  "~space(0)
```
the result:
```
abcdef
```
the reference says:
```
abcdef
```

the code:
```rexx
say "abc  def  "~space(2,"+")
```
the result:
```
abc++def
```
the reference says:
```
abc++def
```

```
.String~startsWith(other)
```
this method gives true if the argument is equal to the characters at the start of the receiver.
this method gives false if not.
this method gives false if the argument is a null string.
this method makes no new string objects from the receiver, so a parse with it can take less time.

```
.String~strip([option] [,chars])
```
strip: a method that takes away characters at the left, at the right, or both
this method gives the receiver without some characters at the left, at the right, or both.
the option argument says where; this method uses only the first letter of it and ignores the other characters.
the code after this has the three options.
```
Both
Leading
Trailing
```
the option on line 1 takes away characters at the left and at the right; it is the default.
the option on line 2 takes away characters only at the left.
the option on line 3 takes away characters only at the right.
the second argument is the set of characters to take away.
by default, this method takes away blanks and the character in the code after this.
```
'09'x
```
if the second argument is a null string, this method takes away no characters.
the code:
```rexx
say "  ab c  "~strip
```
the result:
```
ab c
```
the reference says:
```
ab c
```

the code:
```rexx
say "  ab c  "~strip("L")
```
the result:
```
ab c  
```
the reference says:
```
ab c  
```

the code:
```rexx
say "  ab c  "~strip("t")
```
the result:
```
  ab c
```
the reference says:
```
  ab c
```

the code:
```rexx
say "12.7000"~strip(,0)
```
the result:
```
12.7
```
the reference says:
```
12.7
```

the code:
```rexx
say "0012.700"~strip(,0)
```
the result:
```
12.7
```
the reference says:
```
12.7
```

the code:
```rexx
say "0012.000"~strip(,".0")
```
the result:
```
12
```
the reference says:
```
12
```

```
.String~subChar(n)
```
this method gives the character at the position of the argument in the receiver.
the argument must be a positive whole number.
if the argument is more than the length of the receiver, this method gives an empty string.

```
.String~caselessChangeStr(needle, newneedle [,count])
```
this method gives the receiver with the second argument in the place of each part that is equal to the first argument.
this method does not change the receiver.
the compare to find the first argument is caseless.
if you omit the count argument, this method changes each part that is equal to the first argument.
the count argument is the maximum count of parts to change; it must be zero or a positive whole number.
the code:
```rexx
Say "AbaAbb"~caselessChangeStr("A","")
```
the result:
```
bbb
```
the reference says:
```
bbb
```

the code:
```rexx
Say AbaBabAB~changeStr("ab","xy")
```
the result:
```
ABABABAB
```
the reference says:
```
xyxyxyxy
```

the code:
```rexx
Say AbaBabAB~changeStr("ab","xy",1)
```
the result:
```
ABABABAB
```
the reference says:
```
xyaBabAB
```

```
.String~caselessCompare(string [,pad])
```
this method compares the receiver and the argument string, and the compare is caseless.
this method gives 0 if the two strings are equal.
if not, this method gives the position of the first character that is not equal.
this method puts pad characters at the right of the short string if it must.
the default pad character is a blank.
the code:
```rexx
Say "abc"~caselessCompare("ABC")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "abc"~caselessCompare("Ak")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
Say "ab "~caselessCompare("AB")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "AB "~caselessCompare("ab"," ")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "ab "~caselessCompare("ab","x")
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
Say "abXX "~caselessCompare("ab","x")
```
the result:
```
5
```
the reference says:
```
5
```

```
.String~caselessCompareTo(string [,n] [,length])
```
this method compares the receiver and the argument string, to put them in order, and the compare is caseless.
this method gives 0 if the two strings are equal.
this method gives 1 if the receiver is more.
this method gives -1 if the argument string is more.
the compare starts at the character at the position of the second argument, and uses the count of characters of the length argument, in both strings.
if you omit the second argument, the compare starts at the first character.
the second argument must be a positive whole number.
if you omit the length argument, the compare goes to the end of the receiver.
the length argument must be zero or a positive whole number.
the code:
```rexx
Say "abc"~caselessCompareTo("abc")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "b"~caselessCompareTo("a")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "a"~caselessCompareTo("b")
```
the result:
```
-1
```
the reference says:
```
-1
```

the code:
```rexx
Say "abc"~caselessCompareTo("aBc")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "aBc"~caselessCompareTo("abc")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
Say "000abc000"~caselessCompareTo("111abc111", 4, 3)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~caselessContains(other [,start [,length]])
```
this method gives true if the first argument is a part of the receiver.
this method gives false if the first argument is a null string, or is not a part of the receiver.
the compare is caseless.
by default, this method starts at the first character and goes to the end of the receiver.
the start argument is the position where this method starts.
the start argument must be a positive whole number.
the length argument is the count of characters, from the start, where this method can find the first argument.
the length argument must be zero or a positive whole number.
the code:
```rexx
Say "-abcdef-"~caselessContains("EF")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
Say "-abcdef-"~caselessContains("-", 2, 6)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~caselessContainsWord(phrase [,start])
```
this method gives true if the words of the first argument are in the receiver.
this method gives false if the first argument has no words, or if its words are not in the receiver.
the compare of words is caseless.
more than one blank between words, in the first argument or in the receiver, is the same as one blank for this method.
by default, this method starts at the first word of the receiver.
the start argument is the number of the word where this method starts; it must be a positive whole number.
this method gives false only when the method in the code after this gives 0.
```
caselessWordPos
```
the code:
```rexx
good = "Now is the time for all good men"
say good~caselessContainsWord("the")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~caselessContainsWord("The")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~caselessContainsWord("is the")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~caselessContainsWord("is   the ")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~caselessContainsWord("is time")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~caselessContainsWord("time")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = "Now is the time for all good men"  /* setup from the example before */
say good~caselessContainsWord("time", 5)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~encodeBase64
```
this method gives a new string: the receiver, in the way to write strings in the code after this.
```
base64
```
this method does not change the receiver.
the code:
```rexx
Say "abcdef"~encodeBase64
```
the result:
```
YWJjZGVm
```
the reference says:
```
YWJjZGVm
```

```
.String~endsWith(other)
```
this method gives true if the argument is equal to the characters at the end of the receiver.
this method gives false if not.
this method gives false if the argument is a null string.
this method makes no new string objects from the receiver, so a parse with it can take less time.

```
.String~equals(other)
```
this method gives true if the receiver and the argument are the same string, in a strict compare.
this method gives false if not.
this method does the same compare as the method in the code after this.
```
==
```
the code:
```rexx
say "3"~equals("3")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "33"~equals("3")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "4"~equals("3")
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~floor
```
floor: a method that gives the integer that is the maximum integer not more than a number
this method gives the maximum integer that is not more than the value of the receiver.
first this method makes the receiver rounded with the rexx rules, the same as the code after this.
```
receiving_string+0
```
the result never has an exponent.
if the result has no digits that are not zero, it has no sign.
the code:
```rexx
say 2~floor
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say '-2'~floor
```
the result:
```
-2
```
the reference says:
```
-2
```

the code:
```rexx
say 12.3~floor
```
the result:
```
12
```
the reference says:
```
12
```

the code:
```rexx
say '-12.3'~floor
```
the result:
```
-13
```
the reference says:
```
-13
```

```
.String~format([before] [,after] [,expp] [,expt])
```
format: a method that gives a number in the way you say, with the count of characters you say for each part
this method gives the receiver, a number, rounded and in the way the arguments say.
first this method makes the receiver rounded with the rexx rules, the same as the code after this.
```
receiving_string+0
```
with no arguments, the result is the same as that code.
the before argument is the count of characters for the integer part; by default, the count it needs.
if the before argument is less than the count the integer part needs, with the sign for a negative number, it is an error.
if the before argument is more than the count it needs, this method puts blanks at the left.
the after argument is the count of digits after the point; by default, the count it needs.
if the number has more or less digits after the point than the after argument, this method makes the number rounded, or adds zero digits.
an after argument of 0 makes the number rounded to an integer.
the third argument is the count of characters for the exponent; by default, the count it needs, and it can be zero.
if the third argument is 0, the result has no exponent.
if the third argument is less than the count the exponent needs, it is an error.
the last argument says when the result has an exponent; by default, it is the precision now in use.
the result has an exponent if the integer part needs more digits than the last argument, or the part after the point needs more than two times the last argument.
if the last argument is 0, the result always has an exponent, but not when the exponent is zero.
if the third argument is 0, the result has no exponent, also when the last argument is 0.
if the exponent is zero and the third argument is not zero, this method puts blanks for the exponent: the third argument add 2.
if the exponent is zero and you omit the third argument, the result has no exponent.
the code:
```rexx
say "3"~format(4)
```
the result:
```
   3
```
the reference says:
```
   3
```

the code:
```rexx
say "1.73"~format(4,0)
```
the result:
```
   2
```
the reference says:
```
   2
```

the code:
```rexx
say "1.73"~format(4,3)
```
the result:
```
   1.730
```
the reference says:
```
   1.730
```

the code:
```rexx
say "-.76"~format(4,1)
```
the result:
```
  -0.8
```
the reference says:
```
  -0.8
```

the code:
```rexx
say "3.03"~format(4)
```
the result:
```
   3.03
```
the reference says:
```
   3.03
```

the code:
```rexx
say " - 12.73"~format(,4)
```
the result:
```
-12.7300
```
the reference says:
```
-12.7300
```

the code:
```rexx
say " - 12.73"~format
```
the result:
```
-12.73
```
the reference says:
```
-12.73
```

the code:
```rexx
say "0.000"~format
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "12345.73"~format(, ,2,2)
```
the result:
```
1.234573E+04
```
the reference says:
```
1.234573E+04
```

the code:
```rexx
say "12345.73"~format(,3, ,0)
```
the result:
```
1.235E+4
```
the reference says:
```
1.235E+4
```

the code:
```rexx
say "1.234573"~format(,3, ,0)
```
the result:
```
1.235
```
the reference says:
```
1.235
```

the code:
```rexx
say "12345.73"~format(, ,3,6)
```
the result:
```
12345.73
```
the reference says:
```
12345.73
```

the code:
```rexx
say "1234567e5"~format(,3,0)
```
the result:
```
123456700000.000
```
the reference says:
```
123456700000.000
```

```
.String~substr(n [,length [,pad]])
```
substr: a method that gives a part of a string
this method gives the part of the receiver that starts at the position of the first argument and has the length of the length argument.
this method puts pad characters in the result if it must, to get that length.
the first argument must be a positive whole number.
if the first argument is more than the length of the receiver, the result has only pad characters.
if you omit the length argument, the result is the rest of the receiver.
the default pad character is a blank.
a parse with a template of positions can be a way to get parts of a string too, when you want more than one part.
the code:
```rexx
say "abc"~substr(2)
```
the result:
```
bc
```
the reference says:
```
bc
```

the code:
```rexx
say "abc"~substr(2,4)
```
the result:
```
bc  
```
the reference says:
```
bc  
```

the code:
```rexx
say "abc"~substr(2,6,".")
```
the result:
```
bc....
```
the reference says:
```
bc....
```

```
.String~subWord(n [,length])
```
this method gives the part of the receiver that starts at the word with the number of the first argument and has the count of words of the length argument.
the words are the parts between blanks.
the first argument must be a positive whole number.
if you omit the length argument, the result has all the words to the end of the receiver.
the result has no blanks at the left or at the right.
the result keeps all the blanks between the words in it.
the code:
```rexx
say "Now is the  time"~subWord(2,2)
```
the result:
```
is the
```
the reference says:
```
is the
```

the code:
```rexx
say "Now is the  time"~subWord(3)
```
the result:
```
the  time
```
the reference says:
```
the  time
```

the code:
```rexx
say "Now is the  time"~subWord(5)
```
the result:
```

```
the reference says:
```

```

```
.String~subWords([n] [,length])
```
this method gives an array of the words of the part of the receiver that starts at the word with the number of the first argument and has the count of words of the length argument.
the first argument must be a positive whole number.
the default of the first argument is 1.
if you omit the length argument, the result has all the words to the end of the receiver.
the strings in the array never have blanks at the left or at the right.
you can use this method in a loop on each word of a string.
the code:
```rexx
"Now is the  time"~subWords
```
the result:
```
```
the reference says:
```
.array~of("Now", "is", "the", "time")
```

the code:
```rexx
"Now is the  time"~subWords(2,2)
```
the result:
```
```
the reference says:
```
.array~of("is", "the")
```

the code:
```rexx
"Now is the  time"~subWords(3)
```
the result:
```
```
the reference says:
```
.array~of("the", "time")
```

the code:
```rexx
say "Now is the  time"~subWords(5)
```
the result:
```

```
the reference says:
```
.array~new(0)
```

the code:
```rexx
do word over source~subWords
   say word
end
```
the result:
```
SOURCE
```

```
.String~translate([tableo] [,tablei] [,pad] [,n] [,length])
```
translate: a method that changes each character of a string to the character at the same position in an other list
this method gives the receiver with each character made an other character, or with no change.
the first argument is the list of characters to put in the result.
the second argument is the list of characters to find.
for each character of the receiver, this method tests if it is in the second argument; if it is there, it puts the character at the same position in the first argument.
if the character is not in the second argument, the character does not change.
if a character is more than one time in the second argument, this method uses the first one, at the left.
the result always has the length of the receiver.
the two arguments can have any length.
the default of the second argument is all the characters, as the code after this gives.
```
XRANGE("00"x,"FF"x)
```
the default of the first argument is the null string; this method puts pad characters at its right, or takes away characters at its right, if it must.
the default pad character is a blank.
if you omit the first two arguments and the pad argument, this method changes the letters in lower to letters in upper.
the argument after the pad argument is the position of the first character to change; the default is 1.
the length argument is the count of characters to change; if you omit it, this method changes the characters to the end of the receiver.
this method can change the order of the characters in a string; the last line of the code after this puts the last character of a string of four characters first.
the code:
```rexx
say "abcdef"~translate
```
the result:
```
ABCDEF
```
the reference says:
```
ABCDEF
```

the code:
```rexx
say "abcdef"~translate(, , , 3, 2)
```
the result:
```
abCDef
```
the reference says:
```
abCDef
```

the code:
```rexx
say "abcdef"~translate("12", "ec")
```
the result:
```
ab2d1f
```
the reference says:
```
ab2d1f
```

the code:
```rexx
say "abcdef"~translate("12", "abcd", ".")
```
the result:
```
12..ef
```
the reference says:
```
12..ef
```

the code:
```rexx
say "APQRV"~translate(, "PR")
```
the result:
```
A Q V
```
the reference says:
```
A Q V
```

the code:
```rexx
say "APQRV"~translate(XRANGE("00"X, "Q"))
```
the result:
```
APQ  
```
the reference says:
```
APQ  
```

the code:
```rexx
say "4123"~translate("abcd", "1234", , 2, 2)
```
the result:
```
4ab3
```
the reference says:
```
4ab3
```

the code:
```rexx
say "4123"~translate("abcd", "1234")
```
the result:
```
dabc
```
the reference says:
```
dabc
```

```
.String~trunc([n])
```
this method gives the integer part of the receiver, with the count of digits after the point of the argument.
the receiver must be a number.
the default of the argument is 0: the result is an integer with no point.
the argument must be zero or a positive whole number.
first this method makes the receiver rounded with the rexx rules, the same as the code after this.
```
receiving_string+0
```
then this method does a truncate of the number to that count of digits after the point.
if the result has less digits after the point than the argument, this method adds zero digits at the right.
the result never has an exponent.
if the result has no digits that are not zero, it has no sign.
the code:
```rexx
say 12.3~trunc
```
the result:
```
12
```
the reference says:
```
12
```

the code:
```rexx
say 127.09782~trunc(3)
```
the result:
```
127.097
```
the reference says:
```
127.097
```

the code:
```rexx
say 127.1~trunc(3)
```
the result:
```
127.100
```
the reference says:
```
127.100
```

the code:
```rexx
say 127~trunc(2)
```
the result:
```
127.00
```
the reference says:
```
127.00
```

```
.String~caselessCountStr(needle)
```
this method gives the count of times the argument string is in the receiver.
this method counts a part only when it has no characters of an other part it counts.
the compare is caseless.
the code:
```rexx
Say "a0Aa0A"~caselessCountStr("a")
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
Say "J0kKk0"~caselessCountStr("KK")
```
the result:
```
1
```
the reference says:
```
1
```

```
.String~caselessEndsWith(other)
```
this method gives true if the argument is equal to the characters at the end of the receiver.
this method gives false if not.
this method gives false if the argument is a null string.
the compare is caseless.
this method makes no new string objects from the receiver, so a parse with it can take less time.

```
.String~caselessEquals(other)
```
this method gives true if the receiver and the argument are the same string, in a strict compare that is caseless.
this method gives false if not.
the code:
```rexx
say "a"~caselessEquals("A")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "aa"~caselessEquals("A")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "4"~caselessEquals("3")
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~caselessLastPos(needle [,start [,length]])
```
this method gives the position of the last place where the first argument is in the receiver.
this method gives 0 if the first argument is a null string, or is not in the receiver.
by default, this method starts at the last character and goes back to the first character.
the start argument is the position where this method starts to go back; it must be a positive whole number.
if you omit the start argument, or it is more than the length of the receiver, it is the length of the receiver.
the length argument is the count of characters this method tests; it must be zero or a positive whole number.
the default length is the start argument.
the compare is caseless.
the code:
```rexx
say "abc def ghi"~caselessLastPos(" ")
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
say "abcdefghi"~caselessLastPos(" ")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "efgxyz"~caselessLastPos("XY")
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say "abc def ghi"~caselessLastPos(" ",7)
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say "abc def ghi"~caselessLastPos(" ",7,3)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~caselessMatch(start, other [,n [,length]])
```
this method gives true if the characters of the second argument are equal to the characters of the receiver from the position of the start argument.
this method gives false if not.
the compare is caseless.
the start argument must be a positive whole number.
the third argument is the position in the second argument where the compare starts; the default is 1.
the third argument must be a positive whole number, not more than the length of the second argument.
the length argument says the count of characters of the second argument to compare; it must be a positive whole number.
the third argument and the length argument must say a part that is in the second argument.
this method makes no new string objects from the receiver, so a parse with it can take less time.
the code:
```rexx
say "Saturday"~caselessMatch(6, "day")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "Saturday"~caselessMatch(6, "DAY")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "Saturday"~caselessMatch(6, "SUNDAY", 4, 3)
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "Saturday"~caselessMatch(6, "daytime", 1, 3)
```
the result:
```
1
```
the reference says:
```
1
```

```
.String~caselessMatchChar(n, chars)
```
this method gives true if the character at the position of the first argument is equal to one of the characters of the second argument.
this method gives false if it is not equal to any of them.
the compare is caseless.
the first argument must be a positive whole number.
the code:
```rexx
say "a+b"~caselessMatchChar(2, "+-*/")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "a+b"~caselessMatchChar(1, "+-*/")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "Friday"~caselessMatchChar(3, "aeiou")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "FRIDAY"~caselessMatchChar(3, "aeiou")
```
the result:
```
1
```
the reference says:
```
1
```

```
.String~caselessPos(needle [,start [,length]])
```
this method gives the position of the first argument in the receiver.
the compare is caseless.
this method gives 0 if the first argument is a null string.
this method gives 0 if the first argument is not in the receiver.
this method gives 0 if the start argument is more than the length of the receiver.
the default start is 1, and by default this method goes to the end of the receiver.
the start argument must be a positive whole number.
the length argument is the count of characters, from the start, where this method can find the first argument.
the length argument must be zero or a positive whole number.
the code:
```rexx
say "Saturday"~caselessPos("DAY")
```
the result:
```
6
```
the reference says:
```
6
```

the code:
```rexx
say "abc def ghi"~caselessPos("x")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "abc def ghi"~caselessPos(" ")
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say "abc def ghi"~caselessPos(" ",5)
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
say "abc def ghi"~caselessPos(" ",5,3)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~caselessStartsWith(other)
```
this method gives true if the argument is equal to the characters at the start of the receiver.
this method gives false if not.
this method gives false if the argument is a null string.
the compare is caseless.
this method makes no new string objects from the receiver, so a parse with it can take less time.

```
.String~caselessWordPos(phrase [,start])
```
this method gives the number of the word in the receiver where the words of the first argument start.
this method gives 0 if the first argument has no words.
this method gives 0 if the words of the first argument are not in the receiver.
the compare of words is caseless.
more than one blank between words, in the first argument or in the receiver, is the same as one blank for this method.
by default, this method starts at the first word of the receiver.
the start argument is the number of the word where this method starts; it must be positive.
the code:
```rexx
say "now is the time"~caselessWordPos("the")
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
say "now is the time"~caselessWordPos("The")
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
say "now is the time"~caselessWordPos("IS THE")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say "now is the time"~caselessWordPos("is   the")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say "now is   the time"~caselessWordPos("is   time ")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "To be or not to be"~caselessWordPos("BE")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say "To be or not to be"~caselessWordPos("BE",3)
```
the result:
```
6
```
the reference says:
```
6
```

```
.String~ceiling
```
ceiling: a method that gives an integer that is not less than a number
this method gives an integer that is not less than the value of the receiver.
first this method makes the receiver rounded with the rexx rules, the same as the code after this.
```
receiving_string+0
```
the result never has an exponent.
if the result has no digits that are not zero, it has no sign.
the code:
```rexx
say 2~ceiling
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say '-2'~ceiling
```
the result:
```
-2
```
the reference says:
```
-2
```

the code:
```rexx
say 12.3~ceiling
```
the result:
```
13
```
the reference says:
```
13
```

the code:
```rexx
say '-12.3'~ceiling
```
the result:
```
-12
```
the reference says:
```
-12
```

the code:
```rexx
say '-0.1'~ceiling
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~center(length [,pad])
.String~centre(length [,pad])
```
center: a method that puts a string in the middle of a string with a length you say
centre: the same as center
this method gives a string with the count of characters of the length argument, with the receiver in the middle.
this method puts pad characters at the left and at the right if it must, to get that length.
the length argument must be zero or a positive whole number.
the default pad character is a blank.
if the receiver has more characters than the length argument, this method takes away characters at both ends.
if the count of characters to add or to take away has a remainder when you divide it by two, the right end gets one more of the change than the left end.
the two names are the same method, so you can use both names.
the code:
```rexx
Say abc~center(7)
```
the result:
```
  ABC  
```
the reference says:
```
  ABC  
```

the code:
```rexx
Say abc~CENTER(8,"-")
```
the result:
```
--ABC---
```
the reference says:
```
--ABC---
```

the code:
```rexx
Say "The blue sky"~centre(8)
```
the result:
```
e blue s
```
the reference says:
```
e blue s
```

the code:
```rexx
Say "The blue sky"~centre(7)
```
the result:
```
e blue 
```
the reference says:
```
e blue 
```

```
.String~changeStr(needle, newneedle [,count])
```
this method gives the receiver with the second argument in the place of each part that is equal to the first argument.
if you omit the count argument, this method changes each part that is equal to the first argument.
the count argument is the maximum count of parts to change; it must be zero or a positive whole number.
the code:
```rexx
Say 101100~changeStr("1","")
```
the result:
```
000
```
the reference says:
```
000
```

the code:
```rexx
Say 101100~changeStr("1","X")
```
the result:
```
X0XX00
```
the reference says:
```
X0XX00
```

the code:
```rexx
Say 101100~changeStr("1","X",1)
```
the result:
```
X01100
```
the reference says:
```
X01100
```

the code:
```rexx
r=";say'r=.'r'.'r~changeStr(.,'22'x,2)";say'r="'r'"'r~changeStr(.,'22'x,2)
```
the result:
```
r=";say'r=.'r'.'r~changeStr(.,'22'x,2)";say'r="'r'"'r~changeStr(.,'22'x,2)
```
the reference says:
```
the code writes an exact copy of itself
```

```
.String~hashCode
```
this method gives a string value that the collections in the code after this use.
```
Table  Relation  Set  Bag  Directory
```
two strings that are equal with the method in the code after this get the same value from this method.
```
==
```
the method of the object class with the same name has more facts about it.

```
.String~insert(new [,n [,length [,pad]]])
```
insert: a method that puts a string in an other string, after a position
this method gives the receiver with the first argument put after the character at the position of the second argument.
this method does not change the receiver.
the default of the second argument is 0: the first argument goes at the start.
the second argument and the length argument must be zero or positive whole numbers.
if the second argument is more than the length of the receiver, this method puts pad characters before the new part.
the default length is the length of the first argument.
if the length argument is less than the length of the first argument, this method makes a cut in the first argument at that length.
if not, this method puts pad characters after the first argument to get that length.
the default pad character is a blank.
the code:
```rexx
say "abc"~insert("123")
```
the result:
```
123abc
```
the reference says:
```
123abc
```

the code:
```rexx
say "abcdef"~insert(" ",3)
```
the result:
```
abc def
```
the reference says:
```
abc def
```

the code:
```rexx
say "abc"~insert("123",5,6)
```
the result:
```
abc  123   
```
the reference says:
```
abc  123   
```

the code:
```rexx
say "abc"~insert("123",5,6,"+")
```
the result:
```
abc++123+++
```
the reference says:
```
abc++123+++
```

the code:
```rexx
say "abc"~insert("123", ,5,"-")
```
the result:
```
123--abc
```
the reference says:
```
123--abc
```

```
.String~lastPos(needle [,start [,length]])
```
this method gives the position of the last place where the first argument is in the receiver.
this method gives 0 if the first argument is a null string, or is not in the receiver.
by default, this method starts at the last character and goes back to the first character.
the start argument is the position where this method starts to go back; it must be a positive whole number.
if you omit the start argument, or it is more than the length of the receiver, it is the length of the receiver.
the length argument is the count of characters this method tests; it must be zero or a positive whole number.
the default length is the start argument.
the code:
```rexx
say "abc def ghi"~lastPos(" ")
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
say "abcdefghi"~lastPos(" ")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "efgxyz"~lastPos("xy")
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say "abc def ghi"~lastPos(" ",7)
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say "abc def ghi"~lastPos(" ",7,3)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~left(length [,pad])
```
this method gives a string of the count of characters of the length argument: the left characters of the receiver.
if the receiver is short, this method puts pad characters at the right.
if the length of the receiver is more than the length argument, this method takes away characters at the right.
the default pad character is a blank.
the length argument must be zero or a positive whole number.
this method is the same as the code after this.
```
substr(1, length, pad)
```
the code:
```rexx
say "abc d"~left(8)
```
the result:
```
abc d   
```
the reference says:
```
abc d   
```

the code:
```rexx
say "abc d"~left(8,".")
```
the result:
```
abc d...
```
the reference says:
```
abc d...
```

the code:
```rexx
say "abc  def"~left(7)
```
the result:
```
abc  de
```
the reference says:
```
abc  de
```

```
.String~length
```
this method gives the length of the receiver.
the code:
```rexx
say "abcdefgh"~length
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
say "abc defg"~length
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
say ""~length
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~lower([n] [,length])
```
this method gives a new string: the receiver with some letters made letters in lower.
this method does not change the receiver.
this method changes the characters from the position of the first argument, and the count of them is the length argument.
the other characters do not change.
the first argument must be a positive whole number; if you omit it, this method starts at the first character.
the length argument must be zero or a positive whole number; if you omit it, this method changes the rest of the string.
the code:
```rexx
say "Albert Einstein"~lower
```
the result:
```
albert einstein
```
the reference says:
```
albert einstein
```

the code:
```rexx
say "ABCDEF"~lower(4)
```
the result:
```
ABCdef
```
the reference says:
```
ABCdef
```

the code:
```rexx
say "ABCDEF"~lower(3,2)
```
the result:
```
ABcdEF
```
the reference says:
```
ABcdEF
```

```
.String~makeArray([separator])
```
this method gives an array of the parts of the receiver; it makes a cut in the receiver at each place where the argument string is.
the argument can be any string, also the null string.
if the argument is the null string, each character of the receiver is one item of the array.
if the receiver starts with the argument string, the first item of the array is a null string.
if the receiver ends with the argument string, this method does not add a null item at the end.
if you omit the argument, this method makes a cut in the receiver at the end of each line.
the code:
```rexx
string = "hello".endofline"world".endofline"this is an array."
array = string~makeArray
Say "the second line is:" array[2]
```
the result:
```
the second line is: world
```
the reference says:
```
world
```

the code:
```rexx
string = "hello*world*this is an array."
array = string~makeArray("*")
Say "the third line is:" array[3]
```
the result:
```
the third line is: this is an array.
```
the reference says:
```
this is an array.
```

the code:
```rexx
string = "hello*world*this is an array.*"
array = string~makeArray("*")
```
the result:
```
```
the reference says:
```
the array has 3 items
```

```
.String~makeString
```
this method gives a string with the same string value as the receiver.
if the receiver is an instance of a subclass of the string class, this method gives a string object that is equal to it.
if the receiver is an instance of the string class, this method gives the receiver.

```
.String~match(start, other [,n [,length]])
```
match: a method that tests if a string is equal to a part of an other string at a position
this method gives true if the characters of the second argument are equal to the characters of the receiver from the position of the start argument.
this method gives false if not.
the start argument must be a positive whole number.
the third argument is the position in the second argument where the compare starts; the default is 1.
the third argument must be a positive whole number, not more than the length of the second argument.
the length argument says the count of characters of the second argument to compare; it must be a positive whole number.
the third argument and the length argument must say a part that is in the second argument.
this method makes no new string objects from the receiver, so a parse with it can take less time.
the code:
```rexx
say "Saturday"~match(6, "day")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "Saturday"~match(6, "DAY")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "Saturday"~match(6, "Sunday", 4, 3)
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "Saturday"~match(6, "daytime", 1, 3)
```
the result:
```
1
```
the reference says:
```
1
```

```
.String~matchChar(n, chars)
```
this method gives true if the character at the position of the first argument is equal to one of the characters of the second argument.
this method gives false if it is not equal to any of them.
the first argument must be a positive whole number.
the code:
```rexx
say "a+b"~matchChar(2, "+-*/")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "a+b"~matchChar(1, "+-*/")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "Friday"~matchChar(3, "aeiou")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "FRIDAY"~matchChar(3, "aeiou")
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~max(number [,number ...])
```
max: a method that gives the maximum of some numbers
this method gives the maximum number of the receiver and the arguments.
you can give any count of arguments.
the instruction in the code after this says the way of the result.
```
NUMERIC
```
the code:
```rexx
say 12~max(6,7,9)
```
the result:
```
12
```
the reference says:
```
12
```

the code:
```rexx
say 17.3~max(19,17.03)
```
the result:
```
19
```
the reference says:
```
19
```

the code:
```rexx
say "-7"~max("-3","-4.3")
```
the result:
```
-3
```
the reference says:
```
-3
```

the code:
```rexx
say 1~max(2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)
```
the result:
```
21
```
the reference says:
```
21
```

```
.String~min(number [,number ...])
```
min: a method that gives the minimum of some numbers
this method gives the minimum number of the receiver and the arguments.
you can give any count of arguments.
the instruction in the code after this says the way of the result.
```
NUMERIC
```
the code:
```rexx
say 12~min(6,7,9)
```
the result:
```
6
```
the reference says:
```
6
```

the code:
```rexx
say 17.3~min(19,17.03)
```
the result:
```
17.03
```
the reference says:
```
17.03
```

the code:
```rexx
say "-7"~MIN("-3","-4.3")
```
the result:
```
-7
```
the reference says:
```
-7
```

the code:
```rexx
say 21~min(20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1)
```
the result:
```
1
```
the reference says:
```
1
```

```
.String~upper([n] [,length])
```
this method gives a new string: the receiver with some letters made letters in upper.
this method does not change the receiver.
this method changes the characters from the position of the first argument, and the count of them is the length argument.
the other characters do not change.
the first argument must be a positive whole number; if you omit it, this method starts at the first character.
the length argument must be zero or a positive whole number; if you omit it, this method changes the rest of the string.
the code:
```rexx
say "Albert Einstein"~upper
```
the result:
```
ALBERT EINSTEIN
```
the reference says:
```
ALBERT EINSTEIN
```

the code:
```rexx
say "abcdef"~upper(4)
```
the result:
```
abcDEF
```
the reference says:
```
abcDEF
```

the code:
```rexx
say "abcdef"~upper(3,2)
```
the result:
```
abCDef
```
the reference says:
```
abCDef
```

```
.String~verify(reference [,option [,start [,length]]])
```
verify: a method that tests if each character of a string is in a list of characters
this method gives a number.
the first argument is the list of characters to test with.
the option argument is one of the two options in the code after this; this method uses only the first letter of it.
```
Nomatch
Match
```
with the option on line 1, this method gives 0 if each character of the receiver is in the first argument; if not, it gives the position of the first character that is not in it.
the option on line 1 is the default.
with the option on line 2, this method gives the position of the first character of the receiver that is in the first argument, or 0 if no character is in it.
the start argument is the position where this method starts; the default is 1, and it must be a positive whole number.
the length argument must be zero or a positive whole number; by default this method goes to the end of the receiver.
if the receiver is a null string, this method gives 0, with each option.
if the start argument is more than the length of the receiver, this method gives 0.
if the first argument is a null string, with the option on line 2 this method gives 0.
if the first argument is a null string, with the option on line 1 this method gives the start argument.
the code:
```rexx
say "123"~verify("1234567890")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "1Z3"~verify("1234567890")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say "AB4T"~verify("1234567890")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "AB4T"~verify("1234567890","M")
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
say "AB4T"~verify("1234567890","N")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "1P3Q4"~verify("1234567890", ,3)
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say "123"~verify("",N,2)
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say "ABCDE"~verify("", ,3)
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
say "AB3CD5"~verify("1234567890","M",4)
```
the result:
```
6
```
the reference says:
```
6
```

the code:
```rexx
say "ABCDEF"~verify("ABC","N",2,3)
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say "ABCDEF"~verify("ADEF","M",2,3)
```
the result:
```
4
```
the reference says:
```
4
```

```
.String~word(n)
```
this method gives the word of the receiver with the number of the argument.
the words are the parts between blanks.
if the receiver has less words than the argument, this method gives the null string.
the argument must be a positive whole number.
this method is the same as the code after this.
```
subWord(n, 1)
```
the code:
```rexx
say "Now is the time"~word(3)
```
the result:
```
the
```
the reference says:
```
the
```

the code:
```rexx
say "Now is the time"~word(5)
```
the result:
```

```
the reference says:
```

```

```
.String~wordIndex(n)
```
this method gives the position of the first character of the word of the receiver with the number of the argument.
this method gives 0 if the receiver has less words than the argument.
the argument must be a positive whole number.
the code:
```rexx
say "Now is the time"~wordIndex(3)
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
say "Now is the time"~wordIndex(6)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~wordLength(n)
```
this method gives the length of the word of the receiver with the number of the argument.
this method gives 0 if the receiver has less words than the argument.
the argument must be a positive whole number.
the code:
```rexx
say "Now is the time"~wordLength(2)
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say "Now comes the time"~wordLength(2)
```
the result:
```
5
```
the reference says:
```
5
```

the code:
```rexx
say "Now is the time"~wordLength(6)
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~wordPos(phrase [,start])
```
this method gives the number of the word in the receiver where the words of the first argument start.
this method gives 0 if the first argument has no words, or if its words are not in the receiver.
more than one blank between words, in the first argument or in the receiver, is the same as one blank for this method.
if not, the words must be the same.
by default, this method starts at the first word of the receiver.
the start argument is the number of the word where this method starts; it must be positive.
the code:
```rexx
say "now is the time"~wordPos("the")
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
say "now is the time"~wordPos("The")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "now is the time"~wordPos("is the")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say "now is the time"~wordPos("is   the")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say "now is   the time"~wordPos("is   time ")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say "To be or not to be"~wordPos("be")
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say "To be or not to be"~wordPos("be",3)
```
the result:
```
6
```
the reference says:
```
6
```

```
.String~words
```
this method gives the count of words in the receiver.
the words are the parts between blanks.
the code:
```rexx
say "Now is the time"~words
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say " "~words
```
the result:
```
0
```
the reference says:
```
0
```

```
.String~x2b
```
this method gives the binary value of the receiver, a string of hexadecimal digits.
the receiver can have any length.
each hexadecimal digit gives four binary digits.
the receiver can have blanks between bytes, but not at the left or at the right; this method ignores them.
the length of the result is a whole number times four, and the result has no blanks.
if the receiver is a null string, the result is a null string.
the code:
```rexx
say "C3"~x2b
```
the result:
```
11000011
```
the reference says:
```
11000011
```

the code:
```rexx
say "7"~x2b
```
the result:
```
0111
```
the reference says:
```
0111
```

the code:
```rexx
say "1 C1"~x2b
```
the result:
```
000111000001
```
the reference says:
```
000111000001
```

the code:
```rexx
say "C3"x~c2x~x2b
```
the result:
```
11000011
```
the reference says:
```
11000011
```

the code:
```rexx
say "129"~d2x~x2b
```
the result:
```
10000001
```
the reference says:
```
10000001
```

the code:
```rexx
say "12"~d2x~x2b
```
the result:
```
1100
```
the reference says:
```
1100
```

```
.String~x2c
```
this method changes the receiver, a string of hexadecimal digits, to characters, and gives the string of them.
the result has one byte for each two digits of the receiver.
the receiver can have any length.
if the count of digits divide by two has a remainder, this method puts a 0 digit at the left.
the receiver can have blanks between bytes, but not at the left or at the right; this method ignores them.
if the receiver is a null string, the result is a null string.
the code:
```rexx
say "4865 6c6c 6f"~x2c  /*  ASCII             */
```
the result:
```
Hello
```
the reference says:
```
Hello
```

the code:
```rexx
say "3732 73"~x2c  /*  ASCII             */
```
the result:
```
72s
```
the reference says:
```
72s
```

```
.String~x2d([n])
```
this method gives the decimal value of the receiver, a string of hexadecimal digits.
the result must be a whole number with not more digits than the precision; if not, it is an error.
the receiver can have blanks between bytes, but not at the left or at the right; this method ignores them.
if the receiver is a null string, the result is 0.
if you omit the argument, the receiver is a binary number with no sign.
if you give the argument, the receiver is a number in that count of hexadecimal digits, and it can be negative.
if the left bit is 0, the number is positive; if the left bit is 1, the number is negative.
if the argument is 0, the result is 0.
if it must, this method puts 0 digits at the left of the receiver, or takes away digits at the left, to get the count of digits of the argument.
the code:
```rexx
say "0E"~x2d
```
the result:
```
14
```
the reference says:
```
14
```

the code:
```rexx
say "81"~x2d
```
the result:
```
129
```
the reference says:
```
129
```

the code:
```rexx
say "F81"~x2d
```
the result:
```
3969
```
the reference says:
```
3969
```

the code:
```rexx
say "FF81"~x2d
```
the result:
```
65409
```
the reference says:
```
65409
```

the code:
```rexx
say "46 30"X~x2d  /*  ASCII   */
```
the result:
```
240
```
the reference says:
```
240
```

the code:
```rexx
say "66 30"X~x2d  /*  ASCII   */
```
the result:
```
240
```
the reference says:
```
240
```

the code:
```rexx
say "81"~x2d(2)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
say "81"~x2d(4)
```
the result:
```
129
```
the reference says:
```
129
```

the code:
```rexx
say "F081"~x2d(4)
```
the result:
```
-3967
```
the reference says:
```
-3967
```

the code:
```rexx
say "F081"~x2d(3)
```
the result:
```
129
```
the reference says:
```
129
```

the code:
```rexx
say "F081"~x2d(2)
```
the result:
```
-127
```
the reference says:
```
-127
```

the code:
```rexx
say "F081"~x2d(1)
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say "0031"~x2d(0)
```
the result:
```
0
```
the reference says:
```
0
```

## a class for a string you can change

```
.MutableBuffer
```
buffer: a place in memory that keeps a string; you can change the string in it
mutablebuffer: a class; each instance of it is a buffer
size: the count of characters a buffer can keep
an instance of the mutablebuffer class is a buffer that can do some things with strings in less time, as to put one string after an other.
you can change a buffer with no new object; you can not change a string object that way.
so a program that makes a string from many parts can make less objects with a buffer, and take less time.
the mutablebuffer class has the methods of the object class.

## methods of the mutablebuffer class

```
.MutableBuffer~new([string] [,buffer size])
```
you send this message to the mutablebuffer class, not to a buffer.
this method makes the new buffer.
the first argument is the string the buffer has at the start.
the second argument is the size of the buffer at the start.
the default size is 256.
if the string has more characters than the size, the size is the length of the string.

```
.MutableBuffer~[](n [,length])
```
this method gives the part of the receiver that starts at the character at the position of the first argument and has the length of the length argument.
the first argument must be a positive whole number.
the default length is 1.
if the first argument is more than the length of the receiver, this method gives a null string.
the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))
say s[5]
```
the result:
```
e
```
the reference says:
```
e
```

the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */
say s[18, 3]
```
the result:
```
rst
```
the reference says:
```
rst
```

the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */
say s[25,10]
```
the result:
```
yz
```
the reference says:
```
yz
```

the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */
say s[30]
```
the result:
```

```
the reference says:
```

```

```
.MutableBuffer~[]=
buffer[n [,length]] = new
```
this method gives the receiver with the new string in the place of some characters.
the first index is the position of the first character it takes away; it must be a positive whole number.
the second index is the count of characters it takes away; it must be zero or a positive whole number.
if you omit the second index, the count is the length of the new string.
the part it takes away can go after the end of the receiver.
if the first index is more than the length of the receiver, this method puts blanks before the new string.
the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))
say s[5] = "E"
```
the result:
```
0
```
the reference says:
```
abcdEfghijklmnopqrstuvwxyz
```

the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */
say s[5] = "XXXX"
```
the result:
```
0
```
the reference says:
```
abcdXXXXijklmnopqrstuvwxyz
```

the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */
say s[5] = ""
```
the result:
```
0
```
the reference says:
```
abcdXXXXijklmnopqrstuvwxyz
```

the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */
say s[5, 1] = "="
```
the result:
```
0
```
the reference says:
```
abcd=XXXijklmnopqrstuvwxyz
```

the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */
say s[5, 4] = "="
```
the result:
```
0
```
the reference says:
```
abcd=ijklmnopqrstuvwxyz
```

the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */
say s[10, 2] = "REPLACE"
```
the result:
```
0
```
the reference says:
```
abcd=ijklREPLACEopqrstuvwxyz
```

the code:
```rexx
s = .MutableBuffer~new(xrange("a", "z"))  /* setup from the example before */
say s[4, 99] = ""
```
the result:
```
0
```
the reference says:
```
abc
```

```
.MutableBuffer~append(string ...)
```
this method puts all the argument strings at the end of the string in the buffer.
this method gives the receiver.
if it must, this method makes the size of the buffer more.

```
.MutableBuffer~caselessChangeStr(needle, newneedle [,count])
```
this method gives the receiver with the second argument in the place of each part that is equal to the first argument.
the compare to find the first argument is caseless.
if you omit the count argument, this method changes each part that is equal to the first argument.
the count argument is the maximum count of parts to change; it must be zero or a positive whole number.

```
.MutableBuffer~caselessContains(other [,start [,length]])
```
this method gives true if the first argument is a part of the receiver; if not, it gives false.
this method gives false if the first argument is a null string.
the compare is caseless.
by default, this method starts at the first character and goes to the end of the buffer.
the start argument is the position where this method starts; it must be a positive whole number.
the length argument is the count of characters, from the start, where this method can find the first argument; it must be zero or a positive whole number.
the code:
```rexx
say .mutablebuffer~new('-abcdef-')~caselessContains('EF')
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say .mutablebuffer~new('-abcdef-')~caselessContains('-', 2, 6)
```
the result:
```
0
```
the reference says:
```
0
```

```
.MutableBuffer~caselessContainsWord(phrase [,start])
```
this method gives true if the words of the first argument are in the receiver.
this method gives false if the first argument has no words, or if its words are not in the receiver.
the compare of words is caseless.
more than one blank between words, in the first argument or in the buffer, is the same as one blank for this method.
by default, this method starts at the first word of the buffer.
the start argument is the number of the word where this method starts; it must be a positive whole number.
this method gives false only when the method in the code after this gives 0.
```
caselessWordPos
```
the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")
say good~caselessContainsWord("the")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~caselessContainsWord("The")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~caselessContainsWord("is the")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~caselessContainsWord("is   the ")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~caselessContainsWord("is time")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~caselessContainsWord("time")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~caselessContainsWord("time", 5)
```
the result:
```
0
```
the reference says:
```
0
```

```
.MutableBuffer~caselessCountStr(needle)
```
this method gives the count of times the argument string is in the buffer.
this method counts a part only when it has no characters of an other part it counts.
the compare is caseless.

```
.MutableBuffer~caselessEndsWith(other)
```
this method gives true if the argument is equal to the characters at the end of the buffer; if not, it gives false.
this method gives false if the argument is a null string.
the compare is caseless.
this method makes no new string objects from the buffer, so a parse with it can take less time.

```
.MutableBuffer~caselessLastPos(needle [,start [,length]])
```
this method gives the position of the last place where the first argument is in the buffer.
this method gives 0 if the first argument is a null string, or is not in the buffer.
by default, this method starts at the last character and goes back to the first character.
the start argument is the position where this method starts to go back; it must be a positive whole number.
if you omit the start argument, or it is more than the length of the buffer, it is the length of the buffer.
the length argument is the count of characters this method tests; it must be zero or a positive whole number.
the default length is the start argument.
the compare is caseless.

```
.MutableBuffer~caselessMatch(start, other [,n [,length]])
```
this method gives true if the characters of the second argument are equal to the characters of the buffer from the position of the start argument; if not, it gives false.
the compare is caseless.
the start argument must be a positive whole number.
the third argument is the position in the second argument where the compare starts; the default is 1.
the third argument must be a positive whole number, not more than the length of the second argument.
the length argument says the count of characters of the second argument to compare; it must be a positive whole number.
the third argument and the length argument must say a part that is in the second argument.
this method makes no new string objects from the buffer, so a parse with it can take less time.

```
.MutableBuffer~caselessMatchChar(n, chars)
```
this method gives true if the character at the position of the first argument is equal to one of the characters of the second argument.
this method gives false if it is not equal to any of them.
the compare is caseless.
the first argument must be a positive whole number.

```
.MutableBuffer~caselessPos(needle [,start [,length]])
```
this method gives the position of the first argument in the buffer.
the compare is caseless.
this method gives 0 if the first argument is a null string, if it is not in the buffer, or if the start argument is more than the length of the buffer.
the default start is 1, and by default this method goes to the end of the buffer.
the start argument must be a positive whole number.
the length argument is the count of characters, from the start, where this method can find the first argument; it must be zero or a positive whole number.

```
.MutableBuffer~caselessStartsWith(other)
```
this method gives true if the argument is equal to the characters at the start of the buffer; if not, it gives false.
this method gives false if the argument is a null string.
the compare is caseless.
this method makes no new string objects from the buffer, so a parse with it can take less time.

```
.MutableBuffer~caselessWordPos(phrase [,start])
```
this method gives the number of the word in the buffer where the words of the first argument start.
this method gives 0 if the first argument has no words, or if its words are not in the buffer.
the compare of words is caseless.
more than one blank between words, in the first argument or in the buffer, is the same as one blank for this method.
by default, this method starts at the first word of the buffer.
the start argument is the number of the word where this method starts; it must be positive.

```
.MutableBuffer~changeStr(needle, newneedle [,count])
```
this method gives the receiver with the second argument in the place of each part that is equal to the first argument.
if you omit the count argument, this method changes each part that is equal to the first argument.
the count argument is the maximum count of parts to change; it must be zero or a positive whole number.

```
.MutableBuffer~contains(other [,start [,length]])
```
this method gives true if the first argument is a part of the buffer.
this method gives false if the first argument is a null string, or is not a part of the buffer.
by default, this method starts at the first character and goes to the end of the buffer.
the start argument is the position where this method starts; it must be a positive whole number.
the length argument is the count of characters, from the start, where this method can find the first argument; it must be zero or a positive whole number.
the code:
```rexx
say .mutablebuffer~new('-abcdef-')~contains('ef')
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say .mutablebuffer~new('-abcdef-')~contains('-', 2, 6)
```
the result:
```
0
```
the reference says:
```
0
```

```
.MutableBuffer~containsWord(phrase [,start])
```
this method gives true if the words of the first argument are in the buffer.
this method gives false if the first argument has no words, or if its words are not in the buffer.
more than one blank between words, in the first argument or in the buffer, is the same as one blank for this method.
if not, the words must be the same.
by default, this method starts at the first word of the buffer.
the start argument is the number of the word where this method starts; it must be a positive whole number.
this method gives false only when the method in the code after this gives 0.
```
wordPos
```
the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")
say good~containsWord("the")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~containsWord("The")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~containsWord("is the")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~containsWord("is   the ")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~containsWord("is time")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~containsWord("time")
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
good = .MutableBuffer~new("Now is the time for all good men")  /* setup from the example before */
say good~containsWord("time", 5)
```
the result:
```
0
```
the reference says:
```
0
```

```
.MutableBuffer~countStr(needle)
```
this method gives the count of times the argument string is in the buffer.
this method counts a part only when it has no characters of an other part it counts.

```
.MutableBuffer~delete([n] [,length])
.MutableBuffer~delStr([n] [,length])
```
delete: take away
this method takes away characters from the buffer and gives the receiver.
it takes away the count of characters of the length argument, from the position of the first argument.
the default of the first argument is 1.
if you omit the length argument, or it is more than the count of characters to the end of the buffer, this method takes away all the characters from that position to the end.
the length argument must be zero or a positive integer.
the first argument must be a positive integer.
if the first argument is more than the length of the buffer, or the length argument is zero, this method does not change the buffer.
the two names are the same method.
the second name is there so a buffer has the same method name as a string.

```
.MutableBuffer~delWord(n [,length])
```
this method takes away some words from the buffer.
the words it takes away start at the word with the number of the first argument, and the count of them is the length argument.
if you omit the length argument, or it is more than the count of words to the end, this method takes away all the words from that word to the end.
the length argument must be zero or a positive whole number.
the first argument must be a positive whole number.
if the first argument is more than the count of words in the buffer, this method gives the buffer with no change.
this method also takes away the blanks after the last word it takes away, but not the blanks before the first word it takes away.

```
.MutableBuffer~endsWith(other)
```
this method gives true if the argument is equal to the characters at the end of the buffer; if not, it gives false.
this method gives false if the argument is a null string.
this method makes no new string objects from the buffer, so a parse with it can take less time.

```
.MutableBuffer~getBufferSize
```
this method gives the size of the buffer now.

```
.MutableBuffer~insert(new [,n [,length]])
```
this method gives the receiver with the first argument put after the character at the position of the second argument.
the default of the second argument is 0: the first argument goes at the start.
the second argument and the length argument must be zero or positive integers.
if the second argument is more than the length of the string in the buffer, this method puts pad characters before the new part.
the default length is the length of the first argument.
if the length argument is less than the length of the first argument, this method makes a cut in the first argument at that length.
if not, this method puts pad characters after the first argument to get that length.
the default pad character is a blank.

```
.MutableBuffer~lastPos(needle [,start [,length]])
```
this method gives the position of the last place where the first argument is in the buffer.
this method gives 0 if the first argument is a null string, or is not in the buffer.
by default, this method starts at the last character and goes back to the first character.
the start argument is the position where this method starts to go back; it must be a positive whole number.
if you omit the start argument, or it is more than the length of the buffer, it is the length of the buffer.
the length argument is the count of characters this method tests; it must be zero or a positive whole number.
the default length is the start argument.
the code:
```rexx
x1 = .mutablebuffer~new("abc def ghi")
say x1~lastPos(" ")
```
the result:
```
8
```
the reference says:
```
8
```

the code:
```rexx
x1 = .mutablebuffer~new("abcdefghi")
say x1~lastPos(" ")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
x1 = .mutablebuffer~new("efgxyz")
say x1~lastPos("xy")
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
x1 = .mutablebuffer~new("abc def ghi")
say x1~lastPos(" ",7)
```
the result:
```
4
```
the reference says:
```
4
```

```
.MutableBuffer~length
```
this method gives the length of the data in the buffer.

```
.MutableBuffer~lower([n] [,length])
```
this method gives the receiver with some letters made letters in lower.
this method changes the characters from the position of the first argument, and the count of them is the length argument.
the first argument must be a positive whole number; if you omit it, this method starts at the first character.
the length argument must be zero or a positive whole number; if you omit it, this method changes the rest of the buffer.

```
.MutableBuffer~makeArray([separator])
```
this method gives an array of the parts of the buffer; it makes a cut in the string at each place where the argument string is.
the argument can be any string, also the null string.
if the argument is the null string, each character of the buffer is one item of the array.
if the buffer starts with the argument string, the first item of the array is a null string.
if the buffer ends with the argument string, this method does not add a null item at the end.
if you omit the argument, this method makes a cut at the end of each line.

```
.MutableBuffer~makeString
```
this method gives the string in the buffer, as the string value of the receiver.

```
.MutableBuffer~match(start, other [,n [,length]])
```
this method gives true if the characters of the second argument are equal to the characters of the buffer from the position of the start argument; if not, it gives false.
the start argument must be a positive whole number.
the third argument is the position in the second argument where the compare starts; the default is 1.
the third argument must be a positive whole number, not more than the length of the second argument.
the length argument says the count of characters of the second argument to compare; it must be a positive whole number.
the third argument and the length argument must say a part that is in the second argument.
this method makes no new string objects from the buffer, so a parse with it can take less time.

```
.MutableBuffer~matchChar(n, chars)
```
this method gives true if the character at the position of the first argument is equal to one of the characters of the second argument.
this method gives false if it is not equal to any of them.
the first argument must be a positive whole number.

```
.MutableBuffer~overlay(new [,n [,length [,pad]]])
```
this method puts the first argument on the buffer, in the place of the characters from the position of the second argument.
first, this method makes the first argument have the length of the length argument, with pad characters or by a cut.
this method gives the receiver.
the new part can go after the end of the buffer; then the size of the buffer is more.
the default of the second argument is 1; it must be a positive integer.
the default length is the length of the first argument; it must be zero or a positive integer.
if the second argument is more than the length of the string in the buffer, this method puts pad characters before the new part.
the default pad character is a blank.

```
.MutableBuffer~pos(needle [,start [,length]])
```
this method gives the position of the first argument in the buffer.
this method gives 0 if the first argument is a null string, if it is not in the buffer, or if the start argument is more than the length of the buffer.
the default start is 1, and by default this method goes to the end of the buffer.
the start argument must be a positive whole number.
the length argument is the count of characters, from the start, where this method can find the first argument; it must be zero or a positive whole number.
the code:
```rexx
x1 = .mutablebuffer~new("Saturday")
say x1~pos("day")
```
the result:
```
6
```
the reference says:
```
6
```

the code:
```rexx
x1 = .mutablebuffer~new("abc def ghi")
say x1~pos("x")
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
x1 = .mutablebuffer~new("abc def ghi")  /* setup from the example before */
say x1~pos(" ")
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
x1 = .mutablebuffer~new("abc def ghi")  /* setup from the example before */
say x1~pos(" ",5)
```
the result:
```
8
```
the reference says:
```
8
```

```
.MutableBuffer~replaceAt(new, n [,length])
```
this method gives the receiver with the first argument in the place of some characters.
the characters it takes away start at the position of the second argument, and the count of them is the length argument.
the part it takes away can go after the end of the buffer.
the second argument must be a positive whole number.
the length argument must be zero or a positive whole number.
the default length is the length of the first argument.
if the second argument is more than the length of the string in the buffer, this method puts pad characters before the new part.
the default pad character is a blank.

```
.MutableBuffer~setBufferSize(n)
```
this method makes the size of the buffer the argument, and gives the receiver.
if the argument is less than the length of the string in the buffer, this method makes a cut in the string at that length.
if the argument is 0, this method takes away all the string; then the size is the size that the init method gives.

```
.MutableBuffer~setText(string)
```
this method makes the string in the buffer the argument string, and gives the receiver.

```
.MutableBuffer~space([n] [,pad])
```
this method puts the count of pad characters of the first argument between each two words, and gives the receiver.
the first argument must be zero or a positive whole number; the default is 1.
if the first argument is 0, this method takes away all blanks.
this method always takes away the blanks at the left and at the right.
the default pad character is a blank.

```
.MutableBuffer~startsWith(other)
```
this method gives true if the argument is equal to the characters at the start of the buffer; if not, it gives false.
this method gives false if the argument is a null string.
this method makes no new string objects from the buffer, so a parse with it can take less time.

```
.MutableBuffer~string
```
this method gives the data in the buffer as a string.

```
.MutableBuffer~subChar(n)
```
this method gives the character at the position of the argument in the buffer.
the argument must be a positive whole number.
if the argument is more than the length of the buffer, this method gives an empty string.

```
.MutableBuffer~substr(n [,length [,pad]])
```
this method gives the part of the buffer that starts at the position of the first argument and has the length of the length argument.
this method puts pad characters in the result if it must, to get that length.
the first argument must be a positive integer.
if the first argument is more than the length of the buffer, the result has only pad characters.
if you omit the length argument, the result is the rest of the buffer.
the default pad character is a blank.

```
.MutableBuffer~subWord(n [,length])
```
this method gives the part of the buffer that starts at the word with the number of the first argument and has the count of words of the length argument.
the words are the parts between blanks.
the first argument must be a positive whole number.
if you omit the length argument, the result has all the words to the end of the buffer.
the result has no blanks at the left or at the right, and keeps all the blanks between the words in it.

```
.MutableBuffer~subWords([n] [,length])
```
this method gives an array of the words of the part of the buffer that starts at the word with the number of the first argument and has the count of words of the length argument.
the first argument must be a positive whole number; the default is 1.
if you omit the length argument, the result has all the words to the end of the buffer.
the strings in the array never have blanks at the left or at the right.

```
.MutableBuffer~translate([tableo] [,tablei] [,pad] [,n] [,length])
```
this method gives the receiver with each character made an other character, or with no change.
the first argument is the list of characters to put in the buffer.
the second argument is the list of characters to find.
for each character of the buffer, this method tests if it is in the second argument; if it is there, the character at the same position in the first argument goes in its place.
if the character is not in the second argument, the character does not change.
if a character is more than one time in the second argument, this method uses the first one, at the left.
the two arguments can have any length.
the default of the second argument is all the characters, as the code after this gives.
```
XRANGE('00'x, 'ff'x)
```
the default of the first argument is the null string; this method puts pad characters at its right, or takes away characters at its right, if it must.
the default pad character is a blank.
if you omit the first two arguments and the pad argument, this method changes the letters in lower to letters in upper.
if you omit the first two arguments and give the pad argument, each character of the buffer is made the pad character.
the argument after the pad argument is the position of the first character to change; the default is 1.
the length argument is the count of characters to change; if you omit it, this method changes the characters to the end of the buffer.

```
.MutableBuffer~upper([n] [,length])
```
this method gives the receiver with some letters made letters in upper.
this method changes the characters from the position of the first argument, and the count of them is the length argument.
the first argument must be a positive whole number; if you omit it, this method starts at the first character.
the length argument must be zero or a positive whole number; if you omit it, this method changes the rest of the buffer.

```
.MutableBuffer~verify(reference [,option [,start [,length]]])
```
this method gives a number.
the first argument is the list of characters to test with.
the option argument is one of the two options in the code after this; this method uses only the first letter of it.
```
Nomatch
Match
```
with the option on line 1, this method gives 0 if each character of the buffer is in the first argument; if not, it gives the position of the first character that is not in it.
the option on line 1 is the default.
with the option on line 2, this method gives the position of the first character of the buffer that is in the first argument, or 0 if no character is in it.
the start argument is the position where this method starts; the default is 1, and it must be a positive whole number.
the length argument must be zero or a positive whole number; by default this method goes to the end of the buffer.
if the buffer is empty, this method gives 0, with each option.
if the start argument is more than the length of the buffer, this method gives 0.
if the first argument is a null string, with the option on line 2 this method gives 0.
if the first argument is a null string, with the option on line 1 this method gives the start argument.
the code:
```rexx
say .mutablebuffer~new('123')~verify('1234567890')
```
the result:
```
0
```
the reference says:
```
0
```

the code:
```rexx
say .mutablebuffer~new('1Z3')~verify('1234567890')
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say .mutablebuffer~new('AB4T')~verify('1234567890')
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say .mutablebuffer~new('AB4T')~verify('1234567890','M')
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
say .mutablebuffer~new('AB4T')~verify('1234567890','N')
```
the result:
```
1
```
the reference says:
```
1
```

the code:
```rexx
say .mutablebuffer~new('1P3Q4')~verify('1234567890', ,3)
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say .mutablebuffer~new('123')~verify("",N,2)
```
the result:
```
2
```
the reference says:
```
2
```

the code:
```rexx
say .mutablebuffer~new('ABCDE')~verify("", ,3)
```
the result:
```
3
```
the reference says:
```
3
```

the code:
```rexx
say .mutablebuffer~new('AB3CD5')~verify('1234567890','M',4)
```
the result:
```
6
```
the reference says:
```
6
```

the code:
```rexx
say .mutablebuffer~new('ABCDEF')~verify('ABC',"N",2,3)
```
the result:
```
4
```
the reference says:
```
4
```

the code:
```rexx
say .mutablebuffer~new('ABCDEF')~verify('ADEF',"M",2,3)
```
the result:
```
4
```
the reference says:
```
4
```

```
.MutableBuffer~word(n)
```
this method gives the word of the buffer with the number of the argument.
the words are the parts between blanks.
if the buffer has less words than the argument, this method gives the null string.
the argument must be a positive whole number.
this method is the same as the code after this.
```
receiving_buffer~subWord(n, 1)
```

```
.MutableBuffer~wordIndex(n)
```
this method gives the position of the first character of the word of the buffer with the number of the argument.
this method gives 0 if the buffer has less words than the argument.
the argument must be a positive whole number.

```
.MutableBuffer~wordLength(n)
```
this method gives the length of the word of the buffer with the number of the argument.
this method gives 0 if the buffer has less words than the argument.
the argument must be a positive whole number.

```
.MutableBuffer~wordPos(phrase [,start])
```
this method gives the number of the word in the buffer where the words of the first argument start.
this method gives 0 if the first argument has no words, or if its words are not in the buffer.
more than one blank between words, in the first argument or in the buffer, is the same as one blank for this method.
if not, the words must be the same.
by default, this method starts at the first word of the buffer.
the start argument is the number of the word where this method starts; it must be positive.

```
.MutableBuffer~words
```
this method gives the count of words in the buffer.
the words are the parts between blanks.

