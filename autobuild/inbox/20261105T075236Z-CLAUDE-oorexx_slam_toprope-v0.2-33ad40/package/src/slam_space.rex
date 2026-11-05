#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* slam_space.rex -- read what a person says about where they stand,  */
/*                   and make a plan of it in SLAM Draw words         */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/* Use:                                                               */
/*   rexx slam_space.rex <what you say> <plan.words> [space words]    */
/*                                                                    */
/* SLAM_PKG names the SLAM package (for its lists of words).          */
/* Each word must be known: in SLAM's lists, or in the space words.   */
/* A word I know but can not put in the plan stops me. I do not guess.*/
/* What is not said (how wide a door is, what is past a door) I say,  */
/* and the plan shows it as not known.                                */
/* ------------------------------------------------------------------ */

  parse arg inFile planFile spaceFile .
  if planFile = "" then do
    say "Use: rexx slam_space.rex <what you say> <plan.words> [space words]"
    exit 1
  end
  parse source . . me
  home = filespec("location", me)
  if spaceFile = "" then spaceFile = home || "space_words.md"
  pkg = value("SLAM_PKG", , "ENVIRONMENT")
  /* the SLAM package beside this one in the repo (packages/), or SLAM_PKG */
  if pkg = "" then pkg = home || "../../oorexx_slam_v0.1"

  signal on syntax name spaceError
  reader = .SpaceReader~new
  reader~loadCsv(pkg"/corpus/circular_corpus_v2.csv")
  reader~loadCsv(pkg"/corpus/communications_corpus.csv")
  reader~loadCsv(pkg"/corpus/law_words.csv")
  reader~loadDefs(pkg"/README_SLAM.md")
  reader~loadDefs(spaceFile)
  reader~readFile(inFile)
  reader~sayBack
  reader~writePlan(planFile)
  say "I wrote the plan:" planFile
  exit 0

spaceError:
  co = condition("O")
  if co["CODE"] = 98.900 then say "SLAM Space stopped." co["ADDITIONAL"][1]
  else say "SLAM Space broke:" co["ERRORTEXT"] co["MESSAGE"] "(line" co["POSITION"]")"
  say "  (rc="rc "sigl="sigl "condition="condition("C") "description="condition("D")")"
  exit 2


/* ================================================================== */
::class SpaceReader public
/* ================================================================== */

/* known words that carry no place in a plan                           */
::constant glue "of to at is there and from me in a an the"

::method init
  expose known hallLen hallWid hallDir doors notes said lineNo src
  known = .directory~new
  hallLen = ""
  hallWid = ""
  hallDir = ""
  doors = .array~new
  notes = .array~new
  said = .array~new
  lineNo = 0
  src = ""

/* ---------------- words SLAM knows -------------------------------- */

::method loadCsv
  expose known
  use arg name
  if \SysFileExists(name) then self~fail("I can not find SLAM's list of words:" name". Set SLAM_PKG.")
  s = .stream~new(name)
  rows = s~arrayIn
  s~close
  do i = 2 to rows~items
    parse value rows[i] with w "," .
    w = w~strip~lower
    if w <> "" then known[w] = name
  end

::method loadDefs
  expose known
  use arg name
  if \SysFileExists(name) then self~fail("I can not find the words file:" name".")
  s = .stream~new(name)
  rows = s~arrayIn
  s~close
  do r over rows
    parse var r w ":" d
    w = w~strip~lower
    if d = "" then iterate
    if w = "" then iterate
    if w~verify("abcdefghijklmnopqrstuvwxyz-") = 0 then known[w] = name
  end

/* ---------------- reading what is said ---------------------------- */

::method readFile
  expose lineNo src
  use arg name
  if \SysFileExists(name) then self~fail("I can not find the file" name".")
  src = name
  s = .stream~new(name)
  rows = s~arrayIn
  s~close
  do i = 1 to rows~items
    lineNo = i
    raw = rows[i]~lower~translate("     ", ",;:!?")~space
    text = ""
    do k = 1 to words(raw)
      w = word(raw, k)
      do while right(w, 1) = "."
        w = left(w, length(w) - 1)
      end
      if w <> "" then text = text w
    end
    text = strip(text)
    if text = "" then iterate
    self~readLine(text)
  end

::method readLine
  expose known
  use arg text
  toks = text~makeArray(" ")
  /* 1. each word must be known */
  do k = 1 to toks~items
    t = toks[k]
    if datatype(t, "N") then iterate
    if t = "right" then iterate          /* a word with two senses: see 2 */
    if \known~hasIndex(t) then self~fail("I do not know the word '"t"'. Give me a definition for it in words I know.")
  end
  /* 2. the sense of right: after on or and, it is the side */
  do k = 1 to toks~items
    if toks[k] = "right" then do
      prev = ""
      if k > 1 then prev = toks[k - 1]
      if wordpos(prev, "on and your to") = 0 then self~fail("I know 'right' as a rule, and 'right-side' as a side. Here I can not say which. Say 'on right'.")
      toks[k] = "right-side"
      self~note("I read 'right' as right-side (a side), not as right (a rule): it is after '"prev"'.")
    end
  end
  /* 3. make items: numbers, units, things, and words */
  items = .array~new
  k = 1
  do while k <= toks~items
    t = toks[k]
    nx = ""
    if k < toks~items then nx = toks[k + 1]
    select
      when datatype(t, "N") then items~append(.array~of("NUM", t, k))
      when wordpos(t, "metre metres meter") > 0 then items~append(.array~of("UNIT", "metre", k))
      when t = "front" & nx = "door" then do
        items~append(.array~of("THING", "door", k, "front door"))
        k = k + 1
      end
      when t = "living" & nx = "room" then do
        items~append(.array~of("THING", "room", k, "living room"))
        k = k + 1
      end
      when wordpos(t, "hall hallway") > 0 then items~append(.array~of("THING", "hall", k, "hall"))
      when t = "door" then items~append(.array~of("THING", "door", k, "door"))
      when t = "room" then items~append(.array~of("THING", "room", k, "room"))
      otherwise items~append(.array~of("WORD", t, k))
    end
    k = k + 1
  end
  self~meaning(items)

/* ---------------- what the items say ------------------------------ */
/* each rule takes some items; an item no rule takes, and that is not */
/* glue, stops me                                                     */
::method meaning
  expose hallLen hallWid hallDir doors
  use arg items
  n = items~items
  used = .array~new(n)
  do i = 1 to n
    used[i] = .false
  end
  object = 0          /* the item this line puts in the plan */
  dir = ""            /* AHEAD BEHIND END */
  sides = .array~new
  offset = ""
  offsetRef = ""
  leadsTo = ""
  do i = 1 to n
    it = items[i]
    w1 = self~itemWord(items, i + 1)
    w2 = self~itemWord(items, i + 2)
    w3 = self~itemWord(items, i + 3)
    /* N metre THING : the length of the thing */
    if it[1] = "NUM" then do
      if self~itemKind(items, i + 1) <> "UNIT" then self~fail("after the number" it[2] "I need metre or metres.")
      what = self~itemKind(items, i + 2)
      word2 = w2
      select
        when what = "THING" then do
          if items[i + 2][2] <> "hall" then self~fail("I can give a length to a hall, not to a" items[i + 2][4]".")
          hallLen = it[2]
          object = i + 2
          call markUsed used, i, i + 2
        end
        when word2 = "wide" then do
          hallWid = it[2]
          call markUsed used, i, i + 2
        end
        when word2 = "long" then do
          hallLen = it[2]
          call markUsed used, i, i + 2
        end
        when word2 = "down" then do
          if self~itemKind(items, i + 3) <> "THING" then self~fail("after 'down' I need what you go down: a hall.")
          if items[i + 3][2] <> "hall" then self~fail("you can go down a hall, not a" items[i + 3][4]".")
          offset = it[2]
          call markUsed used, i, i + 3
          if self~itemWord(items, i + 4) = "from" then do
            if self~itemKind(items, i + 5) <> "THING" then self~fail("after 'from' I need a thing I know the place of.")
            offsetRef = items[i + 5][4]
            call markUsed used, i + 4, i + 5
          end
          else offsetRef = "start"
        end
        otherwise self~fail("I do not know what" it[2] "metres says here: I know 'N metres hall', 'N metres wide', 'N metres long' and 'N metres down hall'.")
      end
      iterate
    end
    if it[1] = "WORD" then do
      select
        when it[2] = "ahead" then do
          if w1 <> "of" | w2 <> "me" then self~fail("I know 'ahead of me'. Say it that way.")
          dir = "AHEAD"
          call markUsed used, i, i + 2
        end
        when it[2] = "behind" then do
          if w1 <> "me" then self~fail("I know 'behind me'. Say it that way.")
          dir = "BEHIND"
          call markUsed used, i, i + 1
        end
        when it[2] = "in" then do
          if w1 = "front" then do
            if w2 <> "of" | w3 <> "me" then self~fail("I know 'in front of me'. Say it that way.")
            dir = "AHEAD"
            call markUsed used, i, i + 3
          end
        end
        when it[2] = "at" then do
          if w1 = "end" then do
            if w2 <> "of" then self~fail("I know 'at end of hall'. Say it that way.")
            if self~itemKind(items, i + 3) <> "THING" then self~fail("after 'at end of' I need a hall.")
            if items[i + 3][2] <> "hall" then self~fail("I know the end of a hall, not of a" items[i + 3][4]".")
            dir = "END"
            call markUsed used, i, i + 3
          end
        end
        when it[2] = "on" then do
          if wordpos(w1, "left right-side") = 0 then self~fail("after 'on' I need left or right.")
          sides~append(w1)
          call markUsed used, i, i + 1
          if w2 = "and" then do
            if wordpos(w3, "left right-side") > 0 then do
              if w3 = w1 then self~fail("you say" w1 "two times.")
              sides~append(w3)
              call markUsed used, i + 2, i + 3
            end
          end
        end
        when it[2] = "there" then do
          if w1 = "is" then do
            if self~itemKind(items, i + 2) <> "THING" then self~fail("after 'there is' I need a thing.")
            object = i + 2
            call markUsed used, i, i + 2
          end
        end
        otherwise nop
      end
      iterate
    end
    if it[1] = "THING" then do
      /* door to ROOM : where the door goes */
      if it[2] = "door" then do
        if w1 = "to" then do
          if self~itemKind(items, i + 2) <> "THING" then self~fail("after 'door to' I need a room.")
          if items[i + 2][2] <> "room" then self~fail("a door goes to a room, not to a" items[i + 2][4]".")
          leadsTo = items[i + 2][4]
          call markUsed used, i + 1, i + 2
        end
      end
    end
  end
  /* the object: the item after 'there is', or the first thing */
  if object = 0 then do
    do i = 1 to n
      if items[i][1] = "THING" then do
        if used[i] then iterate
        object = i
        leave
      end
    end
  end
  if object = 0 then self~fail("this line has no thing to put in the plan: a hall, a door or a room.")
  used[object] = .true
  /* each item must be used, or be glue */
  do i = 1 to n
    if used[i] then iterate
    if items[i][1] = "WORD" then do
      if wordpos(items[i][2], self~glue) > 0 then iterate
    end
    self~fail("I know the word '"self~itemText(items[i])"', but I do not know what it puts in the plan here.")
  end
  /* put the object in the plan */
  kind = items[object][2]
  name = items[object][4]
  select
    when kind = "hall" then do
      if dir <> "AHEAD" then self~fail("I need to know where the hall is from you: say 'ahead of me'.")
      hallDir = "AHEAD"
      self~tell("the hall starts where you are, and it is ahead of you.")
    end
    when kind = "door" then do
      if offset <> "" then do
        if sides~items = 0 then self~fail("a door down the hall needs a side: say 'on left' or 'on right'.")
        s = self~placeOf(offsetRef) + offset
        do sd over sides
          self~addDoor(name, sd, s, leadsTo)
        end
      end
      else do
        select
          when dir = "BEHIND" then self~addDoor(name, "start", 0, leadsTo)
          when dir = "AHEAD" then do
            if hallLen = "" then self~fail("I do not know how long the hall is, so I can not put a door at its end.")
            self~addDoor(name, "end", hallLen, leadsTo)
          end
          when dir = "END" then do
            if hallLen = "" then self~fail("I do not know how long the hall is, so I can not put a door at its end.")
            self~addDoor(name, "end", hallLen, leadsTo)
          end
          otherwise self~fail("I do not know where the" name "is. Say where it is from you, or how far down the hall.")
        end
      end
    end
    otherwise self~fail("I can put a hall or a door in the plan, not a" name "by itself.")
  end

::method addDoor
  expose doors hallLen
  use arg name, wall, s, leadsTo
  if hallLen <> "" then do
    if s > hallLen then self~fail("the" name "is" s "metres down the hall, but the hall is" hallLen "metres long.")
  end
  d = .directory~new
  d["NAME"] = name
  d["WALL"] = wall
  d["S"] = s
  d["TO"] = leadsTo
  doors~append(d)
  select
    when wall = "start" then where = "behind you, at the start of the hall"
    when wall = "end" then where = "at the end of the hall, in front of you"
    when wall = "left" then where = s self~metres(s) "down the hall, on your left"
    otherwise where = s self~metres(s) "down the hall, on your right"
  end
  if leadsTo <> "" then self~tell("there is a" name where". it goes to the" leadsTo".")
  else self~tell("there is a" name where".")

::method metres
  use arg n
  if n = 1 then return "metre"
  return "metres"

::method placeOf
  expose doors
  use arg ref
  if ref = "start" then return 0
  found = .array~new
  do d over doors
    if d["NAME"] = ref then found~append(d)
  end
  if found~items = 0 then self~fail("I do not know where the" ref "is. Say where it is first.")
  if found~items > 1 then self~fail("there is more than one" ref". I can not say which one you go from. Give it a name, as 'front door'.")
  return found[1]["S"]

/* ---------------- small helpers ----------------------------------- */

::method itemKind
  use arg items, i
  if i > items~items then return ""
  return items[i][1]

::method itemWord
  use arg items, i
  if i > items~items then return ""
  if items[i][1] = "WORD" then return items[i][2]
  return ""

::method itemText
  use arg it
  if it[1] = "THING" then return it[4]
  return it[2]

::method tell
  expose said lineNo
  use arg text
  said~append("line" lineNo":" text)

::method note
  expose notes lineNo
  use arg text
  notes~append("line" lineNo":" text)

::method fail
  expose src lineNo
  use arg msg
  where = ""
  if lineNo > 0 then where = src "line" lineNo": "
  raise syntax 98.900 array (where || msg)

/* ---------------- saying it back ---------------------------------- */

::method sayBack
  expose said notes hallLen hallWid doors
  say "What I read, in my words:"
  do t over said
    say "  " t
  end
  if hallLen <> "" then say "   the hall is" hallLen "metres long."
  if hallWid <> "" then do
    if hallWid = 1 then say "   the hall is 1 metre wide."
    else say "   the hall is" hallWid "metres wide."
  end
  say "What I chose:"
  do t over notes
    say "  " t
  end
  say "What you do not say (the plan shows it as not known):"
  if doors~items > 0 then say "   how wide a door is. I draw each door 0.8 metres wide."
  do d over doors
    if d["TO"] = "" then do
      if d["WALL"] <> "start" then say "   what is past the" d["NAME"] "on the" self~wallName(d["WALL"])"."
    end
  end
  if hallWid = "" then say "   how wide the hall is. I draw it 1 metre wide."

::method wallName
  use arg wall
  select
    when wall = "left" then return "left"
    when wall = "right-side" then return "right"
    when wall = "start" then return "start"
    otherwise return "end"
  end

/* ---------------- the plan, in SLAM Draw words --------------------- */
/* you stand at the start of the hall and go to the top of the picture */
::method writePlan
  expose hallLen hallWid doors src
  use arg planFile
  if hallLen = "" then self~fail("I can not make a plan: no one says how long the hall is.")
  L = hallLen
  W = hallWid
  if W = "" then W = 1
  mx = 2.4
  my = 1.2
  fw = W + 2 * mx
  fh = L + 2 * my
  dw = 0.8
  wt = 0.08
  out = .array~new
  out~append("-- plan made by SLAM Space from:" src)
  out~append("-- Architecture: Tom Dyer.  Code: Claude (Opus 5.5).")
  out~append("colour floor is #fdf6e3")
  out~append("colour wall is #012169")
  out~append("colour doorway is #ffb81c")
  out~append("colour unknown is #8a8d8f")
  out~append("size" fw "by" fh)
  out~append("page" format(fw * 120, , 0) "wide")
  out~append("paint all white")
  out~append("box floor from" mx my "to" mx + W my + L)
  /* walls */
  out~append("box wall from" mx - wt / 2 my - wt / 2 "to" mx + W + wt / 2 my + wt / 2)
  out~append("box wall from" mx - wt / 2 my + L - wt / 2 "to" mx + W + wt / 2 my + L + wt / 2)
  out~append("box wall from" mx - wt / 2 my - wt / 2 "to" mx + wt / 2 my + L + wt / 2)
  out~append("box wall from" mx + W - wt / 2 my - wt / 2 "to" mx + W + wt / 2 my + L + wt / 2)
  /* doors */
  do d over doors
    s = d["S"]
    y = my + L - s
    label = d["NAME"]
    if d["TO"] <> "" then label = "to" d["TO"]
    select
      when d["WALL"] = "start" then do
        out~append("box doorway size" dw "by" wt * 2 "at" mx + W / 2 y)
        out~append("write wall size 0.2 at" mx + W / 2 y + 0.35 "saying" label)
      end
      when d["WALL"] = "end" then do
        out~append("box doorway size" dw "by" wt * 2 "at" mx + W / 2 y)
        out~append("write wall size 0.2 at" mx + W / 2 y - 0.35 "saying" label)
      end
      when d["WALL"] = "left" then do
        out~append("box doorway size" wt * 2 "by" dw "at" mx y)
        out~append("write wall size 0.2 at" mx - 1.05 y - 0.2 "saying" label)
        if d["TO"] = "" then out~append("write unknown size 0.2 at" mx - 1.05 y + 0.15 "saying room not known")
      end
      otherwise do
        out~append("box doorway size" wt * 2 "by" dw "at" mx + W y)
        out~append("write wall size 0.2 at" mx + W + 1.05 y - 0.2 "saying" label)
        if d["TO"] = "" then out~append("write unknown size 0.2 at" mx + W + 1.05 y + 0.15 "saying room not known")
      end
    end
  end
  /* you, at the start, going to the top */
  out~append("star 3 points red size 0.3 inner 0.35 at" mx + W / 2 my + L - 0.45)
  out~append("write red size 0.16 at" mx + W / 2 my + L - 0.18 "saying you")
  /* lengths */
  out~append("write unknown size 0.18 at" mx + W / 2 my + L / 4 "saying" L "m")
  out~append("write unknown size 0.16 at" mx + W / 2 my - 0.75 "saying hall" W "m wide")
  s2 = .stream~new(planFile)
  s2~open("write replace")
  do line over out
    s2~lineout(line)
  end
  s2~close


::routine markUsed
  use arg used, a, b
  do i = a to b
    used[i] = .true
  end
