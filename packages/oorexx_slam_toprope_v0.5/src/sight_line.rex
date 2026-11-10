#!/usr/bin/env rexx
/* ------------------------------------------------------------------ */
/* sight_line.rex -- who can see what, from a height layer            */
/*                                                                    */
/* Architecture : Tom Dyer                                            */
/* Code         : Claude (Opus 5.5)                                   */
/*                                                                    */
/*   rexx sight_line.rex <grid> <places.words> [words]                */
/*                                                                    */
/* grid: an ESRI ASCII grid in degrees, or Top Rope height words.     */
/* places.words:                                                      */
/*   source <what the grid is>        said with every answer          */
/*   boxes <file>   upright boxes the grid does not hold (buildings):  */
/*                  "box <name> <lat> <lon> <half east> <half north>    */
/*                  <turn> <base asl> <top asl>", one a line            */
/*   place <name> <lat> <lon> eye <m>   (metres above the ground)     */
/*   place <name> <lat> <lon> asl <m>   (metres above the datum)      */
/*   look <from> <to>                                                 */
/*   look <from> <to> within <m> <m>  (each place known to within)    */
/* With "words" the answers are one line each for other programs:     */
/*   sight <from> <to> SEES|CANNOT|SOMETIMES|UNKNOWN <seen> <tried>   */
/* ------------------------------------------------------------------ */
  parse arg gridFile placesFile mode .
  if placesFile = "" then do
    say "Use: rexx sight_line.rex <grid> <places.words> [words]"
    exit 2
  end
  signal on syntax name broke
  places = .directory~new
  looks = .array~new
  source = ""
  boxFile = ""
  s = .stream~new(placesFile)
  if s~open("read") \= "READY:" then do
    say "I can not read" placesFile
    exit 2
  end
  do while s~lines > 0
    ln = s~linein~strip
    if ln = "" | ln~left(2) = "--" then iterate
    parse var ln kind rest
    select
      when kind = "source" then source = rest~strip
      when kind = "boxes" then boxFile = filespec("L", placesFile)rest~strip
      when kind = "place" then do
        parse var rest nm lat lon how val .
        p = .directory~new
        p['LAT'] = lat; p['LON'] = lon
        if how = "asl" then p['ASL'] = val
        else p['EYE'] = val
        places[nm] = p
      end
      when kind = "look" then looks~append(rest~strip)
      otherwise nop
    end
  end
  s~close
  g = .HeightGrid~new(gridFile, source)
  sl = .SightLine~new(g)
  if boxFile \== "" then do
    occ = .BoxOccluders~new(g)
    occ~load(boxFile)
    sl~setOccluder(occ)
    source = source"," occ~items "boxes from" filespec("N", boxFile)
  end
  bad = 0
  do lk over looks
    parse var lk a b "within" ra rb .
    b = b~strip
    if \places~hasIndex(a) | \places~hasIndex(b) then do
      say "look" lk": no such place"
      bad = bad + 1
      iterate
    end
    if ra = "" then do
      d = sl~look(places[a], places[b])
      select
        when d['SEES'] == "UNKNOWN" then v = "UNKNOWN"
        when d['SEES'] then v = "SEES"
        otherwise v = "CANNOT"
      end
      if mode = "words" then do
        n = (v = "SEES")
        if v = "UNKNOWN" then say "sight" a b v 0 0
        else say "sight" a b v n 1
        iterate
      end
      km = format(d['DIST'] / 1000, , 2)"km"
      select
        when v = "UNKNOWN" then say a "?" b "(" || d['WHY']")"
        when v = "SEES" then say a "sees" b "("km"; clear by" format(d['CLEAR'], , 1)"m;" source")"
        when d['BLOCKED_BY'] \== "ground" then say a "cannot see" b "("km"; in the way:" d['BLOCKED_BY']";" source")"
        otherwise do
          at = format(d['BLOCK_FROM'], , 0)"m from" a
          if d~hasIndex('BLOCK_LAT') then at = format(d['BLOCK_LAT'], , 4) format(d['BLOCK_LON'], , 4)"," at
          say a "cannot see" b "("km"; ground at" at "stands" format(-d['CLEAR'], , 1)"m above the line;" source")"
        end
      end
      iterate
    end
    r = sl~spread(places[a], ra, places[b], rb)
    if mode = "words" then do
      say "sight" a b r['VERDICT'] r['SEEN'] r['TRIED']
      iterate
    end
    say a r['VERDICT']~lower~changeStr("cannot", "cannot see")~changeStr("sometimes", "sometimes sees") b ,
        "("r['SEEN'] "of" r['TRIED'] "pairs: within" ra"m of" a "and" rb"m of" b";" source")"
  end
  exit bad

broke:
  co = condition("O")
  if co["CODE"] = 98.900 then say "SLAM sight line stopped." co["ADDITIONAL"][1]
  else say "SLAM sight line broke:" co["ERRORTEXT"] co["MESSAGE"] "(line" co["POSITION"]")"
  exit 2

::requires "sight_line.cls"
