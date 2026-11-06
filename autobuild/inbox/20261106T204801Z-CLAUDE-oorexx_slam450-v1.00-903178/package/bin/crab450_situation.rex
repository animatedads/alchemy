/* crab450_situation.rex - SLAM 450 v0.94: write a Boston Crab situation for
 * fixed craft positions (tests and hand cases; the race writes its own).
 * Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-05.
 * usage: rexx crab450_situation.rex dir seed reported A1 x y z;A2 x y z;...
 * reported: target keys Control knows, comma-separated (e.g. ruby) or -
 * Writes story.txt (situation), cast.words, bind.words, sight.words and
 * places.words; append "# Order — Control to Name" sections to story.txt. */
numeric digits 16
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg dir seed reported craft "|" own   /* v0.97: "A1 x y z;A2 ...|A1 A4" = own team */
if reported=='-' then reported=''
reported=reported~changeStr(',',' ')
.local['SLAM450.GROUND']='GROUND'
g=.Slam450Ground~new(value('SLAM450_HARBOUR_WORDS',,'ENVIRONMENT'),.array~of(-1500,1500,-2000,1000))
w=.Slam450World~new(seed,'HARBOUR',.false,g)
s=.Slam450Situation~new(w)
poses=.directory~new;active=.directory~new
do i=1 to 6;active['A'i]=.false;end
do c over craft~makeArray(';')
  parse var c id x y z .
  if id=='' then iterate
  poses[id]=.array~of(x,y,z,0);active[id]=.true
end
address system 'mkdir -p' dir
n=s~write(dir,w,poses,active,reported,.true,0,own~strip)
say 'SITUATION' dir 'sight lines' n
::requires 'Slam450Squad.cls'
::requires 'Slam450Situation.cls'
