# Boston Crab (oorexx_slam_bostoncrab v0.22): the SLAM reader

Architecture: Tom Dyer. Code: Claude (Opus 5.5). This README: Claude (Opus 5.5).

Part of the SLAM family (Body Slam, Piledriver, Top Rope Slam, Moonsault, ...). Tom Dyer chose the name Boston Crab: it holds a story down until it either gives an answer it can support or taps out with CANNOT TELL.

The reader takes English in, reasons on concepts only, and says English again by translating the concept graph. It never predicts strings. It reads stories, weighs witness statements and records with Reasoned Thought, answers quiz questions without letting the last word win, and checks orders for references the recipient cannot resolve (the Light Brigade's "the guns").

Credits and sources:
- Stories: Gemini (stories 1 to 6 and 8, the acorns) and ChatGPT (story 7, "The Mystery of the Missing Nuts"), supplied by Tom Dyer. The bank witness statements were supplied by Tom Dyer, and the arrest record was added at his request.
- Review and requirements: ChatGPT (v0.4 review). `contrib/chatgpt_sentence_structure/` is ChatGPT's hand-off.
- Terrain picture `orders/light_brigade/north_valley_terrain_gemini.png`: Gemini, prompted by Tom Dyer. It is a rendering, not survey data.
- Vocabulary: Open English WordNet 2025 (CC BY 4.0), read once into SQLite through the estate's Rexx/SQL backend (`DatabaseBackendSelector`, provider REXXSQL-SQLITE). `wordnet/*_wn.src` are imported from it. The database itself (33 MB) is not shipped; `wordnet/build_oewn.rex` and `wordnet/load_sql.rex` rebuild it from the OEWN JSON release.
- Reasoning: the estate's Reasoned Thought (`packages/oorexx_reasoned_thought_v0.1`).
- Historical texts: Raglan's fourth order at Balaklava (1854) is public domain. The Tenerife exchange is reduced to its two key lines.

Tools used: ooRexx 5.3 (Rexx/SQL backend for the WordNet import only). The package has no Python.

Run (with an animatedads/alchemy checkout):

```
export ALCHEMY_REPO_ROOT=/path/to/alchemy
```
```
sh tests/run_stories.sh
```
```
sh tests/run_scramble.sh
```
```
sh testimony_cases/run.sh
```
```
sh qa_cases/run.sh
```
```
sh orders/run.sh
```

New in v0.22: `tests/rexx_pitfalls.rex`, an ooRexx lint run first (test "rexx-pitfalls"), for the traps that reached test runs in v0.13-v0.21:
- P1 a string followed at once by "(" is a routine call (`'"'(x)`, v0.21);
- P2 a string followed at once by x or b is a hex/binary literal (`'text'x`);
- P3 names that differ only in case are one variable (`uNp`/`unP`, the v0.14 crash in SLAM 450's race);
- P4 a loop variable that overwrites a "use arg" name (`en` in compile.rex, v0.20).
`tests/check_pitfalls.sh` also proves the lint still finds all four in `tests/pitfall_cases/bad.rex` and passes `good.rex`. No change to what Boston Crab reads.

New in v0.21 (fetch requests, for ALCHEMYFETCH as designed in the "Browser control for ChatGPT coordination" chat; case `orders/fetch`):
- A URL is one token, as written, and a reference that is CLEAR as itself, like a grid reference: orders.words gives writer and reader `url <the URL>`. Whether it may be fetched is the rules of engagement's question (Legal Effect), not the reader's. "The file at https://..." is that URL.
- Fetch words: fetch, read, get, download, retrieve; document, page, file, release notes, repository, archive, manual, guide, changelog, licence, website, version, latest.
- Names as documents use them: "the README" (the before a name that is no word), "ooRexx" (a capital inside a word), "ooRexx 5.1" (a version number after a name), all-capital names (README, NATO) unless the word is in the dictionary (HUGE stays emphasis). A name modifier fits a longer name it begins: "the ooRexx release notes" fits "the ooRexx 5.1 release notes"; "the latest ooRexx release notes" picks the one the situation calls latest ("... were latest.").
- Names are said back as written ("ooRexx", "README", "KLM"; was "Klm"), and descriptions put adjectives, then names, then kind words before the noun without a stray "and" ("the latest ooRexx 5.1 release notes").
- A dot between digits stays in the number ("5.1").

New in v0.20:
- Ukrainian nouns are declined from a stem by class, as adjectives already were (compile.rex, the standard tables): `nm` masculine hard (пілон, g= а or у for the genitive), `nf` feminine -а (зона; к г х become ц з с before і: ділянці), `nfi` feminine -ія (позиція), `nn` neuter -я (завдання), `nne` neuter -е (поле); `gpl=` where the genitive plural cannot be made by rule (ділянок). 42 nouns moved to stems; irregular ones (міст, мосту) stay listed. Ukrainian forms read: 975 (was about 400).
- `tests/check_uk_forms.sh` (test "uk-forms"): the 226 forms listed by hand up to v0.19, mostly from SLAM 450 commanders' orders, must all still be read. It caught a fault while this was built: a Cyrillic letter is two bytes in UTF-8, so the к→ц rule first looked at half a letter.
- `say|n|i|uk|writer|reader` in orders.words, after each ref of a Ukrainian order: the same things said in Ukrainian, in the nominative, for read-backs: "північно-східний пілон" (northeast pylon, made from north and east via concepts.src within=), "східний причал", "червоні маркери"; names as written ("Observatory Hill"); - where a thing has no Ukrainian words yet. Adjective nominatives now carry their gender (case=nom;gen=m/f/n), so the adjective agrees with the noun.

New in v0.19 (SLAM 450 v0.98's report; case `orders/slam450_v098`):
- Build fix: v0.18 failed to compile when an import ran before the first compile, the order SLAM's check uses. Cause: the package carried a stale `wordnet/wn_map.words` (the v0.17 map, which says "drone" was imported; v0.18 pins drone by hand and has no such concept). The package build now ships the current map, and `tests/check_wn_map.sh` (test "wn-map") fails if the map names any concept the concept files do not define. Import-first on a fresh copy compiles.
- "Не" negates the word after it, not the whole part. Before the command it forbids it ("не кружляйте", how `not`); before another verb it says how: "кружляйте над ним, не зупиняючись" (circle over it without stopping) is circle, how `without stop`.
- The thing a Ukrainian command acts on must be in the situation, as with "the": "уникайте ворожих дронів" (avoid the hostile drones) now finds Crimson and Scarlet, as the English does; the singular "ворожого дрона" is AMBIGUOUS between them. Search verbs are the exception (`*searchverb`: search, find, look, survey, scan): what is searched for may not be known yet.
- Ukrainian adjective stems now take the English adjective's concept. They took the first entry of any part of speech, so "ворожий" meant "a hostile" (the noun) and never matched "hostile drones".
- "The adjacent water" (прилеглу акваторію) is still always-there water: a description does not make it a new thing, only a value (a colour) would.
- A cast name is a name even when it is also a word: "Scarlet was a hostile drone" no longer reads Scarlet as the colour.

New in v0.18 (Red's unread words from SLAM 450's second race; case `orders/slam450_race2`):
- Words added: кружляйте (circle), зупиняючись (stopping), перейдіть (move), продовжуйте (continue), почніть (begin), переключіться (switch), сектор (sector), секунд (seconds), широкий (wide), поблизу (near), підтверджено/знайдено/заявлена (confirmed/found/claimed), якщо (if), або (or), через (after), and the small words.
- Conditions are not orders. "Якщо ціль знайдено, підтверджено або заявлена, повертайтеся ближче до неї" (if the target is found, confirmed or claimed, return closer to it) was three actions (find, confirm, return); now it is one part, verb return, how `if`. In Ukrainian only a command (form=imp) starts a part, and words with no command of their own belong to the command after them. English is unchanged ("fly to ... and hold ..." is still two parts).
- Begin and continue are general verbs: "почніть широкий обліт" (begin a wide orbit) has action orbit, "продовжуйте пошук" action search.
- Filler: ну, ось, ага, так are read and carry nothing. блін and блять (frustration) give `tone|n|frustration|1` in orders.words, `extreme frustration` when said twice or more; never an order.
- Build fix: v0.17's drone and pallet pins hung off WordNet concepts, so a rebuild from scratch (wordnet/reimport.sh) failed its first compile and imported nothing. aircraft is now a hand-built concept anchored in wordnet/anchors.src, and pallet-platform hangs off thing.

New in v0.17 (SLAM 450 v0.97's report; case `orders/slam450_v097`):
- The important one: "Bravo, відскануйте територію між піддонами" (scan the area between the pallets) checked CLEAR with no pallets in the situation, while the English gave NO REFERENT. Cause: v0.13's rule that a Ukrainian noun phrase of a kind the situation lacks is something new. That holds for what is searched for, not for what one steers by. Now a concrete thing right after a place word (між between, біля near, до to, від from, навколо around, над over, на on, у/в in, під under, з from; `place=yes` in lexicon_uk.src) must be in the situation, as "the" requires in English. Abstract things (`*abstract`: acts, events, properties: "від контакту", from contact) are not.
- Part and region nouns (area, territory, zone, region, summit, top; `*partnoun`): "територію між піддонами", "the area between the pallets", check the pallets, not the area.
- Always-there things (`*ambient`: water, sky, air, ground, shoreline): "на воді", "the water", CLEAR with no line in the situation.
- "return to base" (no article after a place word) and "до base" / "до бази" check the base.
- Sense pins: a drone is an aircraft (not a bee), a pallet a platform (not a palette).
- Forms added: пілонами, пілонах, пілонам; база in every case.

New in v0.16 (the unread words from Red's 52 orders in SLAM 450's race; case `orders/slam450_red`):
- About 70 Ukrainian words added from that list: verbs such as обстежте (survey), перевірте (check), чекайте (wait), зупиніться (stop), знижуйтесь (descend), повертайтеся (return), відскануйте (scan), зафіксуйте (log); nouns such as маркер (marker), ділянка (area), вершина (summit), відстань (distance), піддон (pallet); червоний (red) and five more adjective stems; and the small words.
- Negation: "не знижуйтесь" (do not descend) and "do not descend" put `not` in the part's how field in orders.words, so the act is not taken as an order to do it.
- A number ("350 м") is read, and an English word inside a Ukrainian order ("до base") is read as English.
- "The red marker" when the situation has only a group of red markers is AMBIGUOUS: one of them, which one not said (was NO REFERENT).
- A missing noun is supplied only for a value ("до західного", to the western one), so "будьте обережні" (be careful) is no longer "the careful markers".
- "відсканujte" (written half in Latin letters by the commander) stays unread, as it should.

New in v0.15 (SLAM 450 v0.95 live race, seed 1, Red commanding in Ukrainian; case `orders/slam450_race`):
- Crash fixed: a Latin-script phrase with a noun inside a Ukrainian order ("починаючи з Walsh Bay wharves") failed in ukCheck. Cause: ooRexx variable names ignore case, so `unP` in ukNP was the same variable as `uNp` in ukCheck and overwrote it. Renamed; the checker has been scanned for any other pair of names differing only in case (none).
- One order that fails inside Boston Crab no longer stops the batch: it is reported NOT CHECKED with the error, orders.words gets `fail|n|reason` and `end|n|NOT CHECKED`, and the next order is checked.
- Grid references ("E -423 N -402", either order, Cyrillic Е/Н too) are places: CLEAR, the same place for everyone; orders.words gives writer and reader `grid E <east> N <north>`.
- Ukrainian adjectives are declined from a stem with the standard ending tables (`західн|adjhard|=west`, `верхн|adjsoft|=upper`), so every case and number is read. Nouns are still listed form by form.
- Words added: обшукуйте, уникайте (avoid), утримуйтесь (refrain), відведіть (withdraw), повідомте, починаючи, летіть, патрулюйте, частина, поле, дрон, позиція, ціль, висота and others; ворожий (hostile), дружній, лівий, правий.
- Part nouns (part, side, edge, half, end, section; `*partnoun`): "західну частину поля", "the west part of the field" is not itself checked; the field is. In English, "the field" with no field in the situation is NO REFERENT; in Ukrainian, with no article, "поля" is then read as new. A situation that names the race field lets both check it.
- A gerund ("починаючи з", starting from) continues the same order part.

New in v0.14 (gaps found by SLAM 450 v0.94 running the Ukrainian exchange, reported by its Claude (Opus 5.5) chat; case `orders/slam450_gaps`):
- `out/orders.words`: the report for programs. One fact a line, fields split by |: `order|n|from|to|words`, `part|n|i|verb|action|how|words`, `ref|n|i|verdict|words|writer|reader`, `end|n|verdict`. Verb, action and how are concept names, the same for English and Ukrainian. A general verb (conduct, perform, work, do: `*light` in lexicon.src) takes its action from the act named after it ("conduct a search", "вести пошук": search). Each reference says which part it is in, so "fly to the pylon and hold near the base" gives each part its own action and references.
- The situation sentences the reader could not read are listed first ("Situation not read"), so a judgment that rests on them is not taken on trust. The Light Brigade cases now show one ("taking the British guns from the redoubts"), which was always unread and never said.
- A partial name match must end in the same word: "Sydney Opera House" is the Opera House and "Lord Raglan" is Raglan, but "Blues Tower" is never a place called "Blues".
- A plural takes single things only when no group fits: "the Circular Quay wharves" is the group, not also the east wharf at Circular Quay.
- A noun before a noun says which kind: "the finger wharves" are not "the ferry wharves" (two kind words clash, as two slot values do). Adjectives still add ("the soft leaf").
- A capitalised word and a number are a name: "Wharf 3", "Gate 12".
- "обліт" (a fly-around) is the act of orbiting, not an orbit's path: `=orbit:verb` in lexicon_uk.src picks the English word's concept of that part of speech. "Проти годинникової стрілки" (anticlockwise) added.
- Order parts in Ukrainian are split at "та/і/й" or a comma before a verb.
- Not reproduced here: "Blues Tower" passing in an `# Order` section, and "Scarlet was near Blues Point Tower" unread. Both read correctly with v0.13 and v0.14; with the unread list above, SLAM 450's own situation will show which of its sentences are not read.

New in v0.13: Ukrainian orders (Tom Dyer's Sydney search exchange; case `orders/harbour_uk`). The situation is in English and the orders and readbacks in Ukrainian; the checker compares concepts and never notices which language either is in.
- `lexicon_uk.src` lists Ukrainian word forms against the concept an English word has ("пілон|noun|=pylon|num=sg;case=acc"). `compile.rex` resolves `=word` from the English lexicons and marks each entry `lang=uk`, so the realiser still reports in English. Every form is listed; no endings are guessed.
- The tokeniser lower-cases Cyrillic (byte by byte in UTF-8), drops «» and bullets, and splits "Alpha:" labels and brackets.
- Ukrainian has no "the". A noun phrase is a reference to check when it names a kind the situation has things of, carries a slot value (північний, north), or is a name. Other noun phrases (пошук, a search; завдання, a task) say what to do, not which thing.
- A noun left out is found: "від східного причалу до західного" (from the east wharf to the west one) and "від східного до західного причалу". "Північний та південний пілони" is the north one and the south one, each checked.
- A bracketed English gloss of the same reference ("(North Pylon)") is not checked twice.
- Compass values fall within others (concepts.src `within=`): "the north pylon" fits the northeast and the northwest pylon, so with both it is AMBIGUOUS. "The north pylons" (plural) names the pair and is CLEAR. Same in English.
- A message to all: "Bravo, ..." is to Bravo until another call sign, "Усім бортам" (to all aircraft) is to all again. A sender's own "Alpha:" label and call sign are skipped.
- Open questions are kept per sender and addressee, for the whole message. "Bravo, завдання прийняв" (task accepted) answering an order with "Blues Tower" in it is ACK DOES NOT RESOLVE.
- An UNKNOWN NAME line names what the writer may have meant: "blues tower ... nearest: Blues Point Tower".
- Not done: Ukrainian clauses are read word by word (every word must be known, or NOT CHECKED lists it), not parsed for who does what; reports are in English only.

New in v0.12 (from SLAM 450's live harbour run with Boston Crab v0.11; case `orders/harbour_names`):
- A name of two or more words before a noun, with no article, is read as one known thing: "Search Walsh Bay wharves" is checked as "the Walsh Bay wharves". Before, it checked only "Walsh" and left "wharves" unread.
- A name before a noun may name the place the thing is at: "the Walsh Bay wharves" means the finger wharves when the situation says "The finger wharves were at Walsh Bay". It still means a thing that carries the name itself ("the Circular Quay wharves").

New in v0.11 (gaps found by SLAM 450 v0.94's Control, second round, reported by its Claude (Opus 5.5) chat):
- "The Circular Quay wharves" is read as a name before a noun, even though "circular" and "quay" are dictionary words. A name of several words is one attribute (`N:circular_quay`), so it is said as one name: "the Circular Quay wharves", never "the Circular and Quay wharves".
- A verb at the start of an order no longer hides the name after it ("Search Observatory Hill" checks Observatory Hill). Only a capital where no sentence starts makes an ordinary word part of a name. `orders/order_vocab.txt` adds the words orders use (search, hold, orbit, patrol, hover and the rest).
- A name the situation does not have is flagged as UNKNOWN NAME. "Lord Raglan" is the Raglan of the situation.
- "The wharf" no longer matches "the Circular Quay wharves": one is not many. A kind said of a group ("the gunners were enemies") still counts.

New in v0.10 (gaps found by SLAM 450 v0.94's Control, reported by its Claude (Opus 5.5) chat; case `orders/harbour`):
- A place phrase after a reference says which one: "the wharf near the station" is the wharf the situation puts near the station.
- A named place in an order is checked too: if the recipient cannot see Blues Point Tower, that is flagged.
- Orders joined with "and" are read part by part ("fly to the station and land near the northeast pylon").
- `sight.words` may carry a `source` line, which the report repeats. Before, it always said "Top Rope Slam".
- Phrases in the report keep their words ("the northeast pylon", not "the pylon").

New in v0.9 (from Tom Dyer's Sydney harbour run, now `story10`):
- Four pylons stay four pylons. "The northwest pylon" is no longer taken as "the northeast pylon", nor the south shore as the north shore. Two values of one slot (compass direction, colour, size, brightness, height) mean two things. A new word of another slot still adds to the same thing ("a green leaf" then "the soft leaf").
- Capitalised ordinary words run together are a place's name: Circular Quay, Opera House, Blues Point Tower. Before, "Circular" lost its "Quay".
- A later mention keeps the words that tell it from a twin ("the south shore", "the west wharf"), and names are said with each word capitalised.

New in v0.8: the order checker can take who-sees-what from a map. It reads Top Rope Slam v0.2's sight lines (`sight.words`), tied to the situation by `bind.words` (`orders/light_brigade_map`). A map CANNOT rules a thing out for that person. SOMETIMES leaves it in, with the count said beside it.

The development history follows (v0.1 to v0.7, under the working name "reader").

## The rule it enforces

Concept ids are opaque (`C.0007`). Each concept has a gloss ("dog") for people, but
the reader never reads it. `scramble_test.rex` proves this: it shuffles every gloss,
reads the story again, and requires the graph, entities, realised English and
findings to be byte-identical. A deliberately planted leak makes the test fail.

## Files

- `concepts.src`: the concept base (gloss | isa | defs). A value isa its slot, e.g. `green` isa `colour`.
- `lexicon.src`: English labels pointing at concepts. Idioms are their own concepts (`see you tomorrow`).
- `rules.src`: what events need and what they change (`land` needs its agent in the air; `set` needs you to be holding the thing).
- `compile.rex`: gives concepts opaque ids and writes the `.words` files the reader loads.
- `reader.cls`: parsing, reference resolution, world tracking, claim and premise checks.
- `realiser.cls`: English from the graph, by reverse lexicon lookup only.
- `read_story.rex`: the driver. It writes `out/graph.words`, `entities.words`, `realised.txt`, `findings.txt`, `unread.txt` and `gloss_view.txt`.
- `scramble_test.rex`: the non-verbal proof.

## Run

```
rexx compile.rex .
rexx read_story.rex . out
rexx scramble_test.rex 42
```

## What it found in Gemini's story

- "He landed on the grass with a bounce": nothing "he" can mean was in the air. Only the leaf was, so the reader takes it as the leaf.
- "Get off my lawn!": the order's premise is false, because Pip was in the tree. Pip's two replies are both true.
- "a yellow leaf on the ground" may be the same leaf Pip threw.

## Limits (v0.1)

- The lexicon and grammar cover this story's constructions only. Anything else goes to `unread.txt`, never a guess.
- The realiser uses the world's final state, so a fact learnt later can show up early, e.g. "his black nose".
- Definite reference may pick a more specific thing: "the ground" resolved to the lawn, so the realiser says "lawn".
- There are 17 roles, not the 10 first proposed. Place needed at/to/from/path, and the story needed purpose, result and about.

## WordNet (v0.3)

The reader learns vocabulary from Open English WordNet 2025 (CC BY 4.0), and only for the words a text uses.

- `wordnet/build_oewn.rex` reads the JSON once, with json.cls (2m38s for 70 MB).
- `wordnet/load_sql.rex` loads the result into SQLite (`oewn.db`, 82s, once) as one transaction of bound inserts. Tables hold senses in rank order, irregular forms, and the links "kind of", similar, attribute and part.
- `wordnet/wordstore.cls` is the only class that talks SQL. It opens the store through the estate's `DatabaseBackendSelector` with provider `REXXSQL-SQLITE` (oorexx_rexxsql_backend_v0.1: Mark Hessling's Rexx/SQL 2.6B3 with the Alchemy patches) and requires `KEYED_LOOKUP_INDEXED`, so selection fails closed if lookups would scan. Every query binds its values. Importing two stories takes 0.6s.
- `wordnet/env.sh` sets `REXX_PATH` and `LD_LIBRARY_PATH` from `ALCHEMY_REPO_ROOT`. `wordnet/lib/librexxsql.so` is built with the backend's own `tools/build_rexxsql.sh`.
- `wordnet/anchors.src` lists the exact WordNet senses where an imported chain stops and joins the hand-built base. "Travel" is `move`, so crawl inherits move's rules. "Cause to move" is not, so carry doesn't.
- `wordnet/wn_import.rex story.txt` finds each unknown word's lemma, from WordNet's forms or regular endings, and takes the first sense for each part of speech. It follows "kind of" up to an anchor and writes `concepts_wn.src` and `lexicon_wn.src`, with the WordNet id and definition beside every concept.
- Names: a capital at a sentence start counts as a name unless WordNet knows the word. Even then, it's a name if a past-tense verb follows directly ("Pip dropped"). A `cast.words` file beside a story declares names outright.

Rebuild the store from the JSON (with `ALCHEMY_REPO_ROOT` set):

```
sh $ALCHEMY_REPO_ROOT/packages/oorexx_rexxsql_backend_v0.1/tools/build_rexxsql.sh wordnet/lib
. wordnet/env.sh
rexx wordnet/build_oewn.rex /path/to/english-wordnet-2025-json wordnet
rexx wordnet/load_sql.rex wordnet
rexx wordnet/wn_import.rex story5/story.txt
rexx compile.rex .
```

## Questions (v0.4)

`qa.rex storydir` reads the story, then `questions.txt` (`Q|question`, `A|option` lines). Each question becomes a concept query: who or what something is, what kind it is, where something was, whether one existed, or what someone did something to. Each option is parsed and checked against the graph. Every answer carries its evidence kind:

- DIRECT: the story states it.
- MEANING: a `qa_rules.src` meaning applied to what the story states. "Lose" means something of yours is said to be gone or was taken. A "thief" is whoever takes something.
- ELIMINATION: the other options never occur, or only as a guess or a denial.
- SCENE: the weakest kind. The option shares a chapter with the question's place, and nothing better exists.

With no support for any option it answers CANNOT TELL. `key.txt` is opened only after every answer is written.

In v0.4, story 7 (ChatGPT's "Mystery of the Missing Nuts") scored 6/6. Since QA moved onto Reasoned Thought (v0.5) the last word no longer wins by recency. v0.5 scored 4 of 6, and v0.6 scores 5 of 6 with 1 CANNOT TELL and no wrong answers (see Inference, below). Questions 1, 2, 5 and 6 are DIRECT, question 3 is MEANING, and question 4 is SCENE: the story never says Molly was found in the bush. On "Was there a thief?" the reader uses the last word on the matter ("No thief," said Barnaby) and lists the earlier contrary claims as earlier.

Dialogue facts are never world facts. Narration changes the world. A quote is stored as a claim with its speaker. A guessed thing ("Maybe a very small elephant?") or a denied one ("Not a dog") is marked, and never counts as present.

## Review by ChatGPT (4 Nov 2026), and what was done

`contrib/chatgpt_sentence_structure/` is ChatGPT's handoff: a conservative sentence splitter that keeps offsets, plus a review of v0.3.2.

- Its scramble-test finding was right. The old test could pass on two empty outputs. `scramble_test.rex` now finds its own folder, fails on any failed run and on missing or empty outputs, checks that the shuffle moved the glosses, and takes a story folder. Three negative controls fail as they should: a missing story, a planted gloss leak and a crashing run.
- Claims are kept apart from facts (its item 5), as described above.
- Pronouns (its item 6) now check gender, number, kind compatibility and subject continuity. An unresolved pronoun makes the sentence unread, in narration and in quotes.
- Full coverage (its item 7): the copula paths now refuse to drop words. "They are lovely sticks" had silently lost "sticks". There is no general coverage mask yet.
- Not yet done: raw-text offsets and the splitter wired in as a structure mode (its items 1 and 8), and clause nodes for and/if/because/that (its item 3).

## Counting (v0.4.1)

This was added for Gemini's twelve-acorn test (story8a is part 1, story8 is both parts).

- Number words and ordinals: "acorn number three", "the sixth acorn", "the final acorn", "near the first". A number named by a character ("That is acorn number one," Pip chattered) labels the thing just handled.
- "All twelve acorns" is every real acorn, checked against twelve. "One of the seven remaining acorns" checks the seven against what remains.
- "Six acorns remained" is a count claim, checked and never turned into six new acorns.
- `^remain|remains-if|loc!~^rel-in@^soil` in rules.src says what "remain" means. Buried is "in something that is in the soil", so an acorn in a hole in the dirt is buried.
- Picking something up needs it not to be buried.
- `qa.rex` answers "How many X remain?" from the same rule.
- A check that fails right after an unread sentence about the same entity is reported as UNSURE, not as a slip.

Fixed on the way:
- `compile.rex` cut glosses at "~", so 122 imported words (for example climb~01925957-v) had pointed at concepts that did not exist since v0.3.
- A definite noun now prefers something of exactly that kind ("the branch" is not the twig).
- Inflected forms of hand words keep the hand concept ("acorns" is "acorn").

## Witness statements (v0.5)

Story 9 is the bank robbery: three witness statements (Liam Carter, Noah Carter, Emma Price) and one official record, the arrest record Tom Dyer asked for.

Reading:
- A heading containing statement or testimony makes the rest of the section that witness's claims (TESTIMONY). A heading containing record makes it a document's narration (DOCUMENTARY). The tier comes from the lexicon (`statement|section|-|tier=TESTIMONY`), not from the code.
- Inside a statement, "I" is the witness and "we" is the party. A person joins the party by going "with" the witness ("Noah came with me", "Liam came with us too"). "All three of us" is checked against the party's size.
- Clock times (3:10, about 3:20 pm), "until", "before" and "after". "There" is the last place named. "My brother, Noah" names Noah and records the relation. "Alone" and "together" are kept.
- "I heard that...", "Liam told me..." and "I told the police that..." keep the reported clause as content and never as fact.
- After an unread sentence in a statement, the next he or she is unread too, because the person it means may be in the sentence that wasn't read. Emma's "He was standing next to me" is unread for this reason.
- "The shop", when only a supermarket has been named, is taken as the supermarket and reported as a SAME? finding. This applies to buildings only, since the dirt and the lawn are different ground.
- Sense pins: WordNet's first sense of "bank" is a slope and of "officer" is military, so the hand lexicon pins both. New anchors: establishment → building, doer → person, female/male → gendered person, crime, steal. The WordNet importer no longer takes heading capitals as evidence of names.

`testimony.rex storydir` weighs the claims with Reasoned Thought. It asks one kind of question: was each named person at each named place, during the window the sources give for that place? Each location claim becomes a ground. The policies are declared in the file, and each ground names the policy that made it:

- ONE-PLACE: a dated claim that someone was at Y rebuts them being at any other place whose window overlaps.
- HEARSAY: binding scope HEARSAY. No location proposition accepts it.
- SELF-SERVING and PARTIALITY: a claim that gives a suspect an alibi is undercut at its own tier when it comes from the suspect himself or from someone with a stated relation to him. Interest attaches to the sentence, so "I was at the supermarket with Emma" is discounted as a whole.
- ACCOMPLICE: a suspect whom a first-hand claim (his own included) puts at the crime place gains by sharing blame. His claims that put others there are undercut.
- IMPEACHMENT: a witness with any claim that rebuts a settled proposition has all their other claims undercut at their own tier.
- AGAINST-INTEREST is a note and never an upgrade (Tom Dyer: an admission lends no weight to the denial beside it).

Suspects are people a source says did, or who deny doing, a crime. Being at the crime place isn't enough. The crime place is found from concepts in the crime class, not from words.

Result on the given case: Liam at the bank is SETTLED by the arrest record. Liam at the supermarket is NO. Emma is IMPEACHED, because her account had Liam at the supermarket at 3:20. Noah at the bank is CANNOT TELL: his brother's word is an accomplice's, his own is self-serving, his girlfriend's is partial and impeached, and the "alone" report is hearsay. `testimony_cases/` holds the case and four variants (no record, the record placing Liam elsewhere, a neutral witness, the record naming Noah), each with its expected verdicts. Claude (Opus 5.5) wrote these variants. Independent adversarial cases from ChatGPT or Tom are still wanted.

The scramble test now also runs `testimony.rex`. Story 9 passes: every gloss scrambled, every verdict identical.

Limits:
- 37 of the story's 73 sentences and quotes are read. The rest are listed in `unread.txt`: names and ages, "because" and "while" clauses, "how ... could have", "none of us", and imperatives with everyone/nobody.
- Times are clock minutes with no am/pm, on one day.
- A place window is the span of dated claims at that place, from any source.
- Degree words ("very") are consumed but not represented.

## Inference (v0.6)

An inference is a ground as strong as its weakest premise. Its binding is INFERRED. It can make an answer assertible, but it never settles one, because QA counts as settling only a live support that is not an inference. Reasoned Thought's combiner itself is unchanged.

The event sequence ChatGPT asked for (story 7, chapter 4) is two rules in `rules.src`:
- `^shake||...;hiding<-agent!^living`: a thing that shakes by itself, not a living shaker, may hide something. The hiding place is kept until the chapter ends.
- `^emerge||agent.loc<-source/from/^rel-in@hidden`: whatever comes into view came from the place stated ("from the hole") or, failing that, from the hiding place. A location set this way carries the props it came from (`loc-inferred-from` in entities.words).
- "It was Molly the mouse" is now read as an identity. The thing just seen (a nose, which is a body part, which is part of an animal) is Molly's, so Molly is where the nose was, with the same trail.
- Q4, "Who did they find in the bush?": Molly the mouse, SUPPORTED (inferred, not settled). The three premises are all narration, so the inference is DOCUMENTARY. The answer quotes the premises as read.
- `qa_cases/` checks that the rule does not fire where it shouldn't: someone else shakes the bush, the appearance is in a different chapter, or the source is stated. Each must give CANNOT TELL. A fourth case with different words and animals must give the inferred answer. Claude (Opus 5.5) wrote these; independent cases are still wanted.

Q6, "Was there a thief?", stays CANNOT TELL, and that is the reasoned position rather than a gap. Pip's "Someone has taken my nuts!" is testimony. Barnaby's explanation ("I think I know what happened... they fell into this log") and his "No thief" are testimony too. The narration never says how the nuts got into the log, and it never identifies the pile as Pip's: only Pip's "My nuts!" does that. So any continuity ground for "no thief" has a testimony premise, and at equal tier the ordinal combiner gives DISPUTED. The key's "No" depends on taking Barnaby's later word over Pip's earlier one, which is the recency override ChatGPT's review ruled out. A story-based continuity check of told movements was written, then removed, because nothing in the stories exercised it.

Also in v0.6:
- WordNet's first sense of "appear" is "seem", so it is pinned to come into view. Base "shake" is pinned to the hand concept.
- A part already belonging to someone is not taken as someone else's ("Pip scratched his head" had become Molly's head).
- A first mention keeps its article ("A little nose appeared"), even when its owner is learnt later.
- `qa.rex` uses the story folder's compiled words when it has them. The scramble test now compares QA answers as well, and story 7 passes with every gloss scrambled.
- Coverage in story 7: 29 of its 133 sentences and quotes are unread. All five of ChatGPT's coverage examples are listed in `unread.txt` with a reason; none is dropped silently.

## Order checks (v0.7)

`rexx order_check.rex dir` reads `# Order — A to B` and `# Message — A to B` sections from where the recipient stands. Orders are never read into the world. Each definite reference is matched by concept against what the writer and the recipient can each identify. That is everything in the situation, less what the situation says that person cannot see: open world, as the reader's preconditions are.

The report gives one of these for each reference:
- CLEAR
- AMBIGUOUS (the recipient can see several things it could mean)
- NOT VISIBLE (the recipient can see nothing it could mean)
- WRITER AMBIGUOUS (it fits several things the writer can see)
- NO REFERENT (neither can see anything it could mean)
- MEANS DIFFERENT THINGS (each sees exactly one, and they differ)

A plain "the cavalry" in an order defaults to what the recipient commands, when the situation says so. Two more checks: "at" with an event ("at takeoff": waiting at the place, or doing it?), and a bare OK or roger that answers a message still holding an open question. Parts the reader cannot parse are listed as NOT CHECKED and are never passed.

Results:
- Raglan's fourth order is flagged in the second sentence. "The guns" fits the British guns in the redoubts and the Russian guns at the valley's end for Raglan. Lucan can see only the Russian guns, so he will take it as those. "The enemy" behaves the same way, and "the front" has no referent for either man.
- Tenerife: "at takeoff" is flagged, and so is the tower's OK.
- Both controls come back with nothing to clarify.
- The scramble test also covers these reports.

Reader changes made for this:
- "The North Valley" is a name with its article.
- A name before a noun says which one ("the KLM aircraft").
- WordNet adjectives that are capitalised (British, Russian, French) are no longer taken as names.
- "The Russian guns" is never merged with "the British guns".
- cast.words is now read by the reader as well as the importer, so all-caps KLM is a name.
- "Could" and "may" are modals.

Next, map reading. Visibility is stated by hand here ("Lucan could not see the British guns"). It should be computed. Gemini produced a terrain model of the North Valley (`orders/light_brigade/north_valley_terrain_gemini.png`), and Tom Dyer prompted it. The model is Gemini's rendering and has not been checked against survey data. Top Rope Slam already reads map pictures and has a height layer (`height_map.rex at`). The plan:
1. Top Rope reads the picture into heights, using the colour bar and masking the labels and arrow.
2. Top Rope gets a sight-line call: observer, eye height, target.
3. order_check takes its "cannot see" facts from that call, at the tier of the map's source.
