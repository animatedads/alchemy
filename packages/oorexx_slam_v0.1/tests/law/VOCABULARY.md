# a list

```
vocabulary: law.kinds
version: 0.5
written by: Claude (Opus 5.5), 2026-10-30 (0.2: the first list; 0.3: kinds for the Fraud Act 2006 s.2 and the Theft Act 1968 ss.1 and 21; 0.4: cheques, an injury, and NSW Crimes Act 1900 ss.192E and 54; 0.5: a throw, an interview, a past conviction, and hostility to a group)
architecture: Tom Dyer
from: the event names of ChatGPT (GPT-6), OFFENCE_EVENT_CONTRACT_v0.1.md, with the changes in docs/architecture/fixtures/MIGRATION_v0.1_to_v0.2.md;
  and the kinds of evidence of the Computer Misuse Act rule and case files of 2026-10-29
for: every rule file, guidance file and case file in tests/law
```

person: a thing that can know, can say what it can do, and can do it
persons: more than one person
does: a word for do, for one person or thing
did: a word for do, when it is before now
act: a thing that a person does
gets: a word for get
reads: a word for read
runs: a word for run
writes: makes words in a thing
said: a word for say, when it is before now
made: a word for make, when it is before now
used: a word for use, when it is before now
law: a list of rules for each person
record: data that a computer or a person writes at the time of a thing
records: more than one record
element: a part of a rule that has to be true
evidence: data that says an element is true or false
kind: a name for a set of things that are the same in one way
kinds: more than one kind
event: a thing at a place and a time, that a record or a person can say is so
finding: a thing that a rule has to know, that evidence has to say is true or false
offence: a thing that a rule says a person can not do
file: a set of data with a name, in a computer
guidance: words that say how to use a law
case: a thing a person can do, and the evidence for it
only: and no other
definition: the words that say what a word is
access: to read data or a program in a computer, or to run a program in a computer
authorised: the one that has the computer says the person can do it
unauthorised: not authorised
knows: has it in memory as a thing that is true
intends: makes one thing so that an other thing is the result
good: able to do what it has to do
bad: not good
reckless: makes a change, and knows that a bad result can be the result of it, and makes the change all the same
causes: makes
damage: a change that makes a thing less able to do what it can do
serious: a word in the law for damage that is more than a part of the whole
right: what a rule says a person has to do
honest: says what is true, and does what is right
dishonest: not honest
want: to have it as a thing to get
forces: makes a person do a thing that the person does not want
help: do a part of a thing for a person, so that the person can do it
money: a number that a person can give to an other person to get a thing
pays: gives money to
paid: a word for pays, when it is before now
taken: a word for take, when it is before now
given: a word for give, when it is before now
account: a name in a computer, and the money or data in the computer for that name
card: a thing a person can put in a computer, so that the computer can say what account to use
key: a thing that a person can use to say to a computer what the name of the person is
message: words that a person writes to an other person
document: a thing with words, that a person can read
died: is at the end; after it the person can not know or do a thing
loan: money that a person gives to an other person, when the other person has to return it, and more
model: a program that makes words as output, in the way a person can say words
group: a set of persons
sentence: what a rule of the law says a person has to get for an offence
most: more than each other value
meeting: a time and a place where persons are
gain: a thing a person gets, as money or a thing that has a value
had: a word for has, when it is before now
loss: a thing a person can not have now, that the person had before
belongs: is a thing that a person has, by a rule
eyes: the parts of a person that read what is at a place
mind: the part of a person that can know
sees: has as an input, by the eyes or the mind
always: never with an end
proper: right for the use
took: a word for take, when it is before now
demand: words that say to a person to give a thing or to do a thing
threat: words that say a bad thing is to be the result
bank: a place that has the money of a person in a computer, in an account for the person
pay: give money to
payment: money a person gives to an other person, for a thing
got: a word for get, when it is before now
care: what a person does so that no bad result is the result of what the person does
cheque: a document that says to a bank: pay this money to this person, out of my account
hurt: made less able to do what it can do, in a part of the person
body: all the parts of a person
court: a place where the law is used to say if a person did a thing that a rule says the person can not do
guilty: a word a court says of a person that did what a rule says a person can not do
was: a word for is, when it is before now
hand: the part of a person that can take a thing and put it at a place
go: be at one place, and then at an other place
ask: say to a person: say this to me
about: a word for what a thing is for
because: a word that says the thing after it is what made the thing before it

a kind is a name for one thing. a rule file, a guidance file or a case file can use a kind only when it is in this list.

each kind is an event or a finding, and not both. an event is a thing that a record or a person can say is so. a finding is a thing that a rule has to know: what person did the act, what the person knows or intends, if the act is authorised.

the definition of an event can not have a word of a finding in it. the words of a finding are:

```
knows intends unauthorised false dishonest forces reckless offence
```

kind 1:

```
CONTACT_INITIATED
```

it is an event.

a person is the first to say words to an other person, at a place or with a computer.

kind 2:

```
REPRESENTATION_MADE
```

it is an event.

a person says a thing to an other person, as true.

kind 3:

```
MEETING_ARRANGED
```

it is an event.

a person says a time and a place for a meeting.

kind 4:

```
MEETING_ATTENDED
```

it is an event.

a person is at a meeting.

kind 5:

```
DOCUMENT_PRESENTED
```

it is an event.

a person gives a document to an other person to read, or makes it so that the other person can read it.

kind 6:

```
DOCUMENT_MADE
```

it is an event.

a person makes a document, or makes a change to one.

kind 7:

```
THREAT_COMMUNICATED
```

it is an event.

a person says to an other person: if you do not do this, then this bad thing is the result.

kind 8:

```
MONEY_TRANSFERRED
```

it is an event.

money is taken from one person or account, and given to an other person or put in an other account.

kind 9:

```
WORK_PERFORMED
```

it is an event.

a person makes a change to a thing that an other person has.

kind 10:

```
PROPERTY_REMOVED
```

it is an event.

a person takes away a thing, or a part of a thing, that an other person has.

kind 11:

```
CREDIT_OFFERED
```

it is an event.

a person says to an other person that the other person can get a loan.

kind 12:

```
CREDIT_AGREEMENT_ENTERED
```

it is an event.

each of two persons says to the other person: i take the loan and the rules of it.

kind 13:

```
INTEREST_TERMS_STATED
```

it is an event.

a person says what more money a loan has to return, as a number.

kind 14:

```
PAYMENT_INSTRUMENT_HANDED_OVER
```

it is an event.

a person gives a card, or the number for a card, to an other person.

kind 15:

```
CREDENTIAL_USED
```

it is an event.

a card, a key or an account is used to get access to a computer. it does not say what person used it.

kind 16:

```
CREDENTIAL_HELD
```

it is an event.

a person has a card or a key at a time. it does not say that the person used it.

kind 17:

```
PERSON_DIED
```

it is an event.

a person died.

kind 18:

```
BENEFIT_PAYMENT_MADE
```

it is an event.

a group pays money to a person, at each time a rule says.

kind 19:

```
BENEFIT_PAYMENT_RECEIVED
```

it is an event.

money that a group paid to a person gets to an account.

kind 20:

```
NOTIFICATION_NOT_FOUND
```

it is an event.

the records of a place are read, and no message in the records says the thing.

kind 21:

```
MESSAGE_SENT
```

it is an event.

a person gives a message to an other person.

kind 22:

```
READ_RECEIPT
```

it is an event.

a record that a computer has run a message as output. it does not say what person read it.

kind 23:

```
REQUEST_TO_ANOTHER
```

it is an event.

a person says to an other person to run a computer.

kind 24:

```
PHYSICAL_CONTACT
```

it is an event.

a person put a part of the person to a computer.

kind 25:

```
SCREEN_READING
```

it is an event.

a person reads data that a computer has as output, with no input to it.

kind 26:

```
TOOL_DEFAULT
```

it is an event.

a program does a step that the one that runs it does not say to do: the step is in the program from the start.

kind 27:

```
WEAK_SECURITY
```

it is an event.

an account has a key that is the same as a name or a known word.

kind 28:

```
DEFINED_LIMITS
```

it is an event.

a list that says what access a person can have, and that the person gets.

kind 29:

```
MODEL_STATEMENT
```

it is an event.

a model says a thing.

kind 30:

```
PERSON_ACT
```

it is a finding.

the person is the one that did the act: not a card, a key or an account of the person.

kind 31:

```
INTENT_ACCESS
```

it is a finding.

the person intends that the result is access to a program or to data in a computer.

kind 32:

```
INTENT_DAMAGE
```

it is a finding.

the person intends that the result is serious damage.

kind 33:

```
INTENT_FURTHER_OFFENCE
```

it is a finding.

the person intends to do an other offence, or to help a person to do it.

kind 34:

```
KNOWLEDGE_UNAUTHORISED
```

it is a finding.

the person knows that the act or the access is unauthorised.

kind 35:

```
RECKLESSNESS_UNAUTHORISED
```

it is a finding.

the person is reckless as to if the act or the access is unauthorised.

kind 36:

```
RECKLESSNESS_DAMAGE
```

it is a finding.

the person is reckless as to serious damage.

kind 37:

```
AUTHORITY
```

it is a finding.

the act or the access is authorised, or it is unauthorised, by the one that can say.

kind 38:

```
MATERIAL_DAMAGE
```

it is a finding.

the act causes serious damage, or makes a chance of it.

kind 39:

```
MAXIMUM_SENTENCE
```

it is a finding.

the most that the law says a person can get for an offence, as the law says it.

kind 40:

```
AGREEMENT
```

it is a finding.

two persons or more say, each to each, that each one is to do a part of a thing.

kind 41:

```
REPRESENTATION_FALSE
```

it is a finding.

a thing a person said, as true, is false.

kind 42:

```
DOCUMENT_FALSE
```

it is a finding.

a document says it is made by a person or a group, and that person or group did not make it.

kind 43:

```
DEMAND_MADE
```

it is an event.

a person says to an other person: give me this, or do this.

kind 44:

```
DISHONESTY
```

it is a finding.

the act is dishonest, as an honest person sees it, with what the person knows of it.

kind 45:

```
KNOWLEDGE_UNTRUE
```

it is a finding.

the person that said a thing knows that it is, or can be, not true.

kind 46:

```
INTENT_GAIN_LOSS
```

it is a finding.

the person intends a gain for the person or an other person, or a loss, or a chance of a loss, for an other person.

kind 47:

```
BELONGS_TO_ANOTHER
```

it is a finding.

the thing belongs to a person that is not the person that took it.

kind 48:

```
INTENT_PERMANENT_DEPRIVATION
```

it is a finding.

the person intends that the one it belongs to can not have it again, always.

kind 49:

```
MENACES
```

it is a finding.

what the person said with the demand is a threat of a bad thing, more than a part of what a person can take.

kind 50:

```
DEMAND_UNWARRANTED
```

it is a finding.

the person that made the demand does not have, as true in the mind of the person, both that the demand is right and that the threat is a proper way to make it.

kind 51:

```
CHEQUE_DRAWN
```

it is an event.

a person writes a cheque for an account and gives it to an other person, as a payment.

kind 52:

```
CHEQUE_DISHONOURED
```

it is an event.

a bank does not pay the money a cheque says: the person the cheque is for does not get it.

kind 53:

```
PERSON_INJURED
```

it is an event.

a part of the body of a person is hurt.

kind 54:

```
PROPERTY_OBTAINED
```

it is a finding.

the person got a thing that belongs to an other person, or got a gain, or made an other person have a loss.

kind 55:

```
UNLAWFUL_OR_NEGLIGENT
```

it is a finding.

what the person did, or did not do, is a thing that a rule says a person can not do, or is not the care a good person takes.

kind 56:

```
CAUSED
```

it is a finding.

the act, or the thing the person did not do, is what made the result: with no act, no result.

kind 57:

```
GRIEVOUS_BODILY_HARM
```

it is a finding.

the hurt to the body of the person is serious, as the law says.

kind 58:

```
OBJECT_THROWN
```

it is an event.

a person makes a thing go from the hand of the person, at a person, at a thing, or at a place.

kind 59:

```
INTERVIEW_ANSWER
```

it is an event.

a person says a thing to persons that ask the person about an event, and a record of it is made.

kind 60:

```
PREVIOUS_CONVICTION
```

it is an event.

a record of a court says that, at a time before, a court said the person was guilty of a thing.

kind 61:

```
HOSTILITY_TO_GROUP
```

it is a finding.

the person did the act because of what group the person took an other person to be in.
