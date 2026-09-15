strategy = .PlayerStrategy~new("test",0.5,0.1,1.0)

cfg1 = .GameConfig~new(5,10,1000,4,246813579)
t1 = .PokerTable~new("seat-a",cfg1)
c1 = .array~new
do name over .array~of("Ada","Grace","GROK","GEMINI","Hugo","Eve","Frank","Maya")
  c1~append(.Player~new(name,1000,strategy))
end
o1 = t1~seatPlayersRandomized(c1)

cfg2 = .GameConfig~new(5,10,1000,4,246813579)
t2 = .PokerTable~new("seat-b",cfg2)
c2 = .array~new
do name over .array~of("Ada","Grace","GROK","GEMINI","Hugo","Eve","Frank","Maya")
  c2~append(.Player~new(name,1000,strategy))
end
o2 = t2~seatPlayersRandomized(c2)

if o1~items \= o2~items then raise syntax 93.900 array("replay seating size mismatch")
order1 = ""
order2 = ""
do i = 1 to o1~items
  if i > 1 then do
    order1 ||= ","
    order2 ||= ","
  end
  order1 ||= o1[i]~name
  order2 ||= o2[i]~name
end

if order1 \= order2 then raise syntax 93.900 array("same seed did not replay seating")
if order1 = "Ada,Grace,GROK,GEMINI,Hugo,Eve,Frank,Maya" then
  raise syntax 93.900 array("test seed unexpectedly preserved fixed seating")

/* Seating consumes the table RNG. Same seed + same seating shuffle must leave
   the subsequent RNG state identical too. */
do i = 1 to 20
  if t1~randomInt(1,1000000) \= t2~randomInt(1,1000000) then
    raise syntax 93.900 array("post-seating RNG state not replayable")
end

say "PASS seeded random initial seating:" order1
exit 0
::requires "poker.cls"
