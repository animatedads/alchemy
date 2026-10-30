# a rule

```
rule: cma1990.s3za
extent: E.W.
section: 3ZA
written by: Claude (Opus 5.5), 2026-10-29, standing in for the small model (Luna or Haiku)
source: Computer Misuse Act 1990, section 3ZA(1), as in source/cma1990_offences.txt
licence of the source: Open Government Licence v3.0, Crown copyright
```

person: a thing that can know, can say what it can do, and can do it
law: a list of rules for each person
element: a part of a rule that has to be true
elements: more than one element
offence: a thing that a rule says a person can not do
authorised: the one that has the computer says the person can do it
unauthorised: not authorised
knows: has it in memory as a thing that is true
intends: makes one thing so that an other thing is the result
damage: a change that makes a thing less able to do what it can do
serious: a word in the law for damage that is more than a part of the whole
reckless: makes a change, and knows that damage can be the result of it, and makes the change all the same
causes: makes
evidence: data that says an element is true or false

the law, as code:

```
(1) A person is guilty of an offence if—
(a) the person does any unauthorised act in relation to a computer;
(b) at the time of doing the act the person knows that it is unauthorised;
(c) the act causes, or creates a significant risk of, serious damage of a material kind; and
(d) the person intends by doing the act to cause serious damage of a material kind or is reckless as to whether such damage is caused.
```

element 1:

```
the person does any unauthorised act in relation to a computer
```

the person makes a change to a computer, and the change is unauthorised.

it takes evidence of:

```
PERSON_ACT AUTHORITY
```

element 2:

```
at the time of doing the act the person knows that it is unauthorised
```

at the time of the change, the person knows that the change is unauthorised.

it takes evidence of:

```
KNOWLEDGE
```

element 3:

```
the act causes, or creates a significant risk of, serious damage of a material kind
```

the change causes serious damage, or makes a chance of serious damage.

it takes evidence of:

```
MATERIAL_DAMAGE
```

element 4:

```
the person intends by doing the act to cause serious damage of a material kind or is reckless as to whether such damage is caused
```

the person intends that the result of the change is serious damage, or the person is reckless as to the damage.

it takes evidence of:

```
INTENT_DAMAGE RECKLESSNESS
```

rule: when element 1, element 2, element 3 and element 4 are true, the offence is true.
