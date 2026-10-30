# a rule

```
rule: crimes1900nsw.s192E
extent: NSW
section: 192E
written by: Claude (Opus 5.5), 2026-10-30, standing in for the small model (Luna or Haiku) of the chain
  legislation -> small model -> SLAM -> Reasoned Thought; not yet written by that model
source: Crimes Act 1900 (NSW), section 192E(1), NSW Parliamentary Counsel exchange XML
text: law/source_corpus/nsw_ny_20261030/nsw/state/act-1900-040_2026-10-01.xml, SHA-256
  516dcc9f4eaf821d8450f36774678e1ece10eeb201d01eab501abe2a2d14d954, the version valid 2026-10-01 to 2026-10-28
history: "Part 4AA (ss 192B-192M): Ins 2009 No 99": the section did not exist before that Act; an event before
  it is under the older law (for a cheque, s.178B valueless cheques, repealed by the same Act)
about: section 192B says a deception can be conduct that makes a computer do what the person may not make it
  do, so the use of a card and its number at a machine is an event this rule can be about
not modelled: section 192B(2), a deception has to be intended or reckless
licence of the source: the NSW legislation website's terms (Crown copyright, State of New South Wales)
```

person: a thing that can know, can say what it can do, and can do it
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
made: a word for make, when it is before now
said: a word for say, when it is before now
knows: has it in memory as a thing that is true
good: able to do what it has to do
right: what a rule says a person has to do
honest: says what is true, and does what is right
dishonest: not honest
sees: has as an input
belongs: is a thing that a person has, by a rule
gets: a word for get
got: a word for get, when it is before now
money: a number that a person can give to an other person to get a thing
gain: a thing a person gets, as money or a thing that has a value
had: a word for has, when it is before now
loss: a thing a person can not have now, that the person had before
deceives: makes a person, or a computer, take as true a thing that is not true
most: more than each other value
sentence: what a rule of the law says a person has to get for an offence
years: a way to count time

it is about an event of kind:

```
REPRESENTATION_MADE DOCUMENT_PRESENTED CREDENTIAL_USED CHEQUE_DRAWN
```

the most the law says:

```
section: 192E
Maximum penalty—Imprisonment for 10 years
```

the law, as code:

```
(1) A person who, by any deception, dishonestly—
(a) obtains property belonging to another, or
(b) obtains any financial advantage or causes any financial disadvantage, is guilty of the offence of fraud.
```

element 1:

```
A person who, by any deception
```

the person is the one that did the act.

it takes evidence of:

```
PERSON_ACT
```

element 2:

```
by any deception
```

what the person said or did deceives a person or a computer.

it takes evidence of:

```
REPRESENTATION_FALSE
```

element 3:

```
dishonestly
```

the person is dishonest, as an honest person sees it, with what the person knows.

it takes evidence of:

```
DISHONESTY
```

element 4:

```
obtains property belonging to another
```

```
obtains any financial advantage or causes any financial disadvantage
```

the person got a thing that belongs to an other person, or got a gain, or made an other person have a loss.

it takes evidence of:

```
PROPERTY_OBTAINED
```

rule: when element 1, element 2, element 3 and element 4 are true, the offence is true.
