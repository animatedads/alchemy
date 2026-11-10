# Train SLAM on the hallway: the word round

Architecture: Tom Dyer.
Code, definitions and this page: Claude (Opus 5.5).

I could not run SLAM's word loop (`bin/words.rex`) in my session: the
permission check stopped me running code from the alchemy clone. So these
steps are for your machine. Each command is on its own line. Run them in
order from `packages/oorexx_slam_v0.1`. Put this folder (`slam_space`) next
to `packages`, or change the paths.

## 0. Set up

```
export REXX_PATH=$PWD/src
```

## 1. Open the round (Claude opens it: these are Claude's words to define)

```
rexx bin/words.rex open hallway "Claude (Opus 5.5)" -- a plan of a home from what a person says where they stand -- ../../slam_space/hallway.txt
```

## 2. Load: SLAM says which words it does not know

```
rexx bin/words.rex load hallway
```

What I expect SLAM to say is not known (15 words): ahead, behind, door,
down, front, hall, hallway, left, living, meter, metre, metres, on, room,
wide. Digits are numbers, so 4, 1 and 2 are fine. If SLAM lists other
words, the round is right and my list is wrong. Send me SLAM's list.

## 3. The second sense of "right"

SLAM knows `right` only as a rule ("what a rule says a person has to do").
Here it is a side. Add this line to the end of `corpus/senses.csv`:

```
right-side,sense right side,"the word right, as a side: the side of you that is not your left"
```

Then answer the sense question. The answer for `right` is `side`:

```
rexx bin/words.rex sense hallway "Tom Dyer"
```

## 4. Claude's definitions

```
rexx bin/words.rex define hallway "Claude (Opus 5.5)" -- ../../slam_space/space_words.md
```

Read `corpus/rounds/hallway.review.md`. Each of the 29 definitions uses only
words SLAM knows, or words defined on a line before it.

## 5. Load again: the round closes when no word is missing

```
rexx bin/words.rex load hallway
```

## 6. Accept (not by Claude: the writer can not accept their own words)

```
rexx bin/words.rex accept hallway "Tom Dyer"
```

## 7. Read the hallway and draw the plan

```
cd ../../slam_space
```

```
SLAM_PKG=../packages/oorexx_slam_v0.1 rexx slam_space.rex hallway.txt hallway_plan.words
```

```
rexx ../slam_draw/slam_draw.rex hallway_plan.words hallway_plan.svg
```

## What left and right rest on

No words can say which side is left. Only a thing two persons share can.
Here that thing is the picture: SLAM Draw counts across from the left side.
So `left` is defined as the side of a picture where the count across starts.
Your left is the left of the picture, when you turn the picture so you go to
its top. The plan is drawn that way: you stand at the bottom and go up.
