/* Sydney webcam conservative motion admission mask, V5V 80x45.
   Motion mask only: source observations and excluded regions are retained.
   Rows are zero-indexed, bounds inclusive. Not a surveyed water-plane map. */
numeric digits 20
parse arg output preview
if output='' then exit 2
left=.array~new(45);right=.array~new(45)
do y=0 to 44
 left[y+1]=80;right[y+1]=-1
end
/* Explicit hand-reviewed provisional visible-water polygon as row intervals.
   The diagonal harbour foreground and bridge/right shore remain excluded. */
do y=27 to 44
 select
  when y=27 then do; l=0; r=22; end
  when y=28 then do; l=0; r=42; end
  when y<=32 then do; l=0; r=50; end
  when y<=34 then do; l=0; r=53; end
  when y<=36 then do; l=0; r=50; end
  when y<=38 then do; l=0; r=48; end
  when y=39 then do; l=0; r=47; end
  when y=40 then do; l=16; r=47; end
  when y=41 then do; l=18; r=47; end
  when y=42 then do; l=20; r=46; end
  when y=43 then do; l=25; r=45; end
  otherwise do; l=30; r=45; end
 end
 left[y+1]=l;right[y+1]=r
end
call stream output,'c','open write replace'
call lineout output,'row|first_x|last_x|authority'
allowed=0
pixels=''
do y=0 to 44
 call lineout output,y||'|'||left[y+1]||'|'||right[y+1]||'|PROVISIONAL_WATER_MOVEMENT_ONLY'
 do x=0 to 79
  if x>=left[y+1] & x<=right[y+1] then do
   allowed=allowed+1
   pixels=pixels||d2c(48)||d2c(178)||d2c(225)
  end
  else pixels=pixels||d2c(7)||d2c(14)||d2c(22)
 end
end
call stream output,'c','close'
if preview<>'' then do
 call charout preview,'P6'||'0a'x||'80 45'||'0a'x||'255'||'0a'x||pixels,1
 call stream preview,'c','close'
end
say 'MASK READY: keep='allowed 'excluded='3600-allowed 'total=3600'
exit 0
