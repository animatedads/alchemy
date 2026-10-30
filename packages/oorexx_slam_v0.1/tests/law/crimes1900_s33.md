# a rule

```
rule: crimes1900nsw.s33
extent: NSW
section: 33
written by: Claude (Opus 5.5), 2026-10-30, standing in for the small model (Luna or Haiku) of the chain
  legislation -> small model -> SLAM -> Reasoned Thought; not yet written by that model
source: Crimes Act 1900 (NSW), section 33, subsection (1), NSW Parliamentary Counsel exchange XML
text: law/source_corpus/nsw_ny_20261030/nsw/state/act-1900-040_2026-10-01.xml, SHA-256
  516dcc9f4eaf821d8450f36774678e1ece10eeb201d01eab501abe2a2d14d954, the version valid 2026-10-01 to 2026-10-28
history: "Am 1989 No 218, Subst 2007 No 38": this text from 2007
not modelled: subsection (2), with intent to resist or prevent a lawful arrest; subsection (3), the jury's
  verdict under section 35 instead; section 4, the meaning of grievous bodily harm
licence of the source: the NSW legislation website's terms (Crown copyright, State of New South Wales)
```

person: a thing that can know, can say what it can do, and can do it
persons: more than one person
law: a list of rules for each person
element: a part of a rule that has to be true
elements: more than one element
offence: a thing that a rule says a person can not do
evidence: data that says an element is true or false
writes: makes words in a thing
record: data that a computer or a person writes at the time of a thing
event: a thing at a place and a time, that a record or a person can say is so
kind: a name for a set of things that are the same in one way
about: a word for what a thing is for
section: a part of a law, with a number
does: a word for do, for one person or thing
did: a word for do, when it is before now
act: a thing that a person does
good: able to do what it has to do
bad: not good
care: what a person does so that no bad result is the result of what the person does
made: a word for make, when it is before now
had: a word for has, when it is before now
hurt: made less able to do what it can do, in a part of the person
body: all the parts of a person
serious: a word in the law for a thing that is more than a part of the whole
intends: makes one thing so that an other thing is the result
gets: a word for get
skin: the part of the body that is the first part a thing gets to, when it gets to the body
break: a place where a thing is not whole
most: more than each other value
sentence: what a rule of the law says a person has to get for an offence
years: a way to count time

it is about an event of kind:

```
PERSON_INJURED
```

the most the law says:

```
section: 33
Maximum penalty—Imprisonment for 25 years
```

the law, as code:

```
(1) A person who—
(a) wounds any person, or
(b) causes grievous bodily harm to any person, with intent to cause grievous bodily harm to that or any other person is guilty of an offence.
```

element 1:

```
A person who
```

the person is the one that did the act.

it takes evidence of:

```
PERSON_ACT
```

element 2:

```
wounds any person
```

```
causes grievous bodily harm to any person
```

the act is what made the hurt.

it takes evidence of:

```
CAUSED
```

element 3:

```
wounds
```

```
grievous bodily harm
```

the hurt is a break in all of the skin of the person, or the hurt to the body of the person is serious, as the law says.

it takes evidence of:

```
WOUND GRIEVOUS_BODILY_HARM
```

element 4:

```
with intent to cause grievous bodily harm to that or any other person
```

the person intends that the act makes hurt to the body of a person that is serious, as the law says.

it takes evidence of:

```
INTENT_GRIEVOUS_HARM
```

rule: when element 1, element 2, element 3 and element 4 are true, the offence is true.
