s1 = .CasinoSeed~normalize(424242)
s2 = .CasinoSeed~normalize(424242)
if s1 \= s2 then raise syntax 93.900 array("replay seed normalization changed value")
if s1 \= 424242 then raise syntax 93.900 array("replay seed mismatch")

fresh1 = .CasinoSeed~fresh
call SysSleep 0.01
fresh2 = .CasinoSeed~fresh
if fresh1 = fresh2 then raise syntax 93.900 array("fresh seed did not reroll")
if fresh1 > 999999999 | fresh2 > 999999999 then raise syntax 93.900 array("fresh seed exceeds NoSQLServer INTEGER-safe range")
if \datatype(fresh1, "W") | \datatype(fresh2, "W") then raise syntax 93.900 array("fresh seed is not whole under default numeric digits")

r1 = .PokerRandom~new(s1)
r2 = .PokerRandom~new(s2)
do i = 1 to 20
  if r1~nextInt(1,1000000) \= r2~nextInt(1,1000000) then
    raise syntax 93.900 array("same seed did not replay RNG sequence")
end

say "PASS fresh seed and replay seed contract"
exit 0
::requires "poker.cls"
