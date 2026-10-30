# a rule

```
rule: fraud2006.s2
extent: E.W.
section: 2
written by: Claude (Opus 5.5), 2026-10-30, standing in for the small model (Luna or Haiku) of the chain
  legislation -> small model -> SLAM -> Reasoned Thought; not yet written by that model
source: Fraud Act 2006, section 2(1) and (2), https://www.legislation.gov.uk/ukpga/2006/35/section/2
text: the Fraud Act 2006 XML, SHA-256 b3a267d809d0b3e1a6a872b29c4192bdd47515ca70d8335d3c46f6714a0c4107
  (tests/law/source/MANIFEST_LEGISLATION.md); section 2 extends to England and Wales, not to Scotland
offence: fraud, section 1(1) and (2)(a): a person in breach of section 2 is guilty of fraud
about: section 2(5) says a representation can be made to a system or device, so the use of a card and its
  number at a machine is an event this rule can be about; and section 2(4) says a representation may be
  express or implied, so a cheque given as payment (an implied representation that it will be paid) is too
licence of the source: Open Government Licence v3.0, Crown copyright
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
said: a word for say, when it is before now
knows: has it in memory as a thing that is true
intends: makes one thing so that an other thing is the result
good: able to do what it has to do
right: what a rule says a person has to do
honest: says what is true, and does what is right
dishonest: not honest
sees: has as an input
gets: a word for get
money: a number that a person can give to an other person to get a thing
gain: a thing a person gets, as money or a thing that has a value
had: a word for has, when it is before now
loss: a thing a person can not have now, that the person had before
most: more than each other value
sentence: what a rule of the law says a person has to get for an offence
years: a way to count time

it is about an event of kind:

```
REPRESENTATION_MADE DOCUMENT_PRESENTED CREDENTIAL_USED CHEQUE_DRAWN
```

the most the law says:

```
section: 1
on conviction on indictment, to imprisonment for a term not exceeding 10 years
```

the law, as code:

```
(1) A person is in breach of this section if he—
(a) dishonestly makes a false representation, and
(b) intends, by making the representation—
(i) to make a gain for himself or another, or
(ii) to cause loss to another or to expose another to a risk of loss.
(2) A representation is false if—
(a) it is untrue or misleading, and
(b) the person making it knows that it is, or might be, untrue or misleading.
```

element 1:

```
makes a false representation
```

the person says a thing as true, or does a thing that says it, to a person or to a computer.

it takes evidence of:

```
PERSON_ACT
```

element 2:

```
it is untrue or misleading
```

what the person said is not true, or makes a person get a thing that is not true out of it.

it takes evidence of:

```
REPRESENTATION_FALSE
```

element 3:

```
the person making it knows that it is, or might be, untrue or misleading
```

the person knows that what the person said is, or can be, not true.

it takes evidence of:

```
KNOWLEDGE_UNTRUE
```

element 4:

```
dishonestly makes a false representation
```

the person is dishonest, as an honest person sees it, with what the person knows.

it takes evidence of:

```
DISHONESTY
```

element 5:

```
intends, by making the representation
```

```
to make a gain for himself or another
```

```
to cause loss to another or to expose another to a risk of loss
```

the person intends a gain for the person or an other person, or a loss, or a chance of a loss, for an other person.

it takes evidence of:

```
INTENT_GAIN_LOSS
```

rule: when element 1, element 2, element 3, element 4 and element 5 are true, the offence is true.
