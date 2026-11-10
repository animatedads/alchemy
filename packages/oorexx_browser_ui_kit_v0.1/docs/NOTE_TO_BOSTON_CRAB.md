# Note to Boston Crab's chat: fetch orders for ALCHEMYFETCH

From: Claude (Opus 5.5), browser-ui-fixtures lane, 9 November 2026. Architecture: Tom Dyer.
Tom carries this note (Boston Crab has no mailbox lane yet).

## What ALCHEMYFETCH is

ALCHEMYFETCH is a new mailbox principal. Agents send it orders to fetch documents from allowlisted sites
(SourceForge first) that they cannot reach themselves. It handles every order in Tom's four steps:

1. Is it an order?
2. Is it lawful? (Legal Effect rules of engagement)
3. Execute.
4. Report.

Today step 1 reads only `FETCH URL`. Free text (for example "read me the ooRexx README") should come to you. That
is the same job as checking a battlefield order, with documents instead of places.

## What would be needed

1. **Fetch verbs.** Treat these as one action, `fetch`: fetch, get, download, retrieve, read (as in "read me"),
   open.
2. **Documents as things.** A situation line says what exists and where. For example:
   `The ooRexx README was at https://sourceforge.net/p/oorexx/code-0/HEAD/tree/README.txt.`
3. **A web address is a place.** Read it the way you read a grid reference: CLEAR as itself, and the same place
   for everyone. Give it in `orders.words` the way a grid reference is given, e.g. `url https://...`.
4. **Negation works as it already does.** "Do not fetch X" is a part marked `not`. ALCHEMYFETCH will never
   execute it.

## Cases, with the verdict I'd expect

Situation for every case:

```
# Situation
The ooRexx README was at https://sourceforge.net/p/oorexx/code-0/HEAD/tree/README.txt.
The BSF4ooRexx README was at https://sourceforge.net/p/bsf4oorexx/code/HEAD/tree/README.txt.
The ooRexx release was on SourceForge.
# Order — Claude to Alchemyfetch
```

| Order | Expected |
|---|---|
| Fetch https://sourceforge.net/p/oorexx/code-0/HEAD/tree/README.txt. | CLEAR, a web address |
| Fetch the README. | AMBIGUOUS: the ooRexx README or the BSF4ooRexx README |
| Fetch the ooRexx README. | CLEAR, carrying its address |
| Read me the ooRexx README. | CLEAR, action fetch |
| Fetch the release notes. | NO REFERENT, REQUIRES CLARIFICATION |
| Fetch the file from the site we discussed. | NO REFERENT for "the site we discussed" |
| Do not fetch the BSF4ooRexx README. | part marked `not`: a prohibition, never executed |
| The README was updated yesterday. | a message, not an order: no action |

## What ALCHEMYFETCH does with your report

- **Only CLEAR goes on to the rules of engagement.** Anything else goes back to the sender as the clarification
  request, in your words.
- **The address it fetches is the one in your `url` field.** It is never guessed from the text.

Credits: Architecture Tom Dyer. Note written by Claude (Opus 5.5). Boston Crab: its own chat.
