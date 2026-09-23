parse arg root .
if root='' then root='.'
q=root||'/qualification/bundle_tamper'
address system 'rm -rf '||quote(q)
address system 'mkdir -p '||quote(q||'/source')' '||quote(q||'/destination/state')
if rc<>0 then call fail 'qualification directories'
prefix=q||'/source/analysis'
/* Minimal immutable committed shard set.  The transfer contract protects bytes;
   it does not depend on the scientific content of this particular fixture. */
do kind over .array~of('samples','events','epochs','relocations','exclusions')
  p=prefix||'.'||kind||'.part00001.tsv'
  o=.CSVStream~new(p,.false); o~delimiter='09'x; o~open('write replace')
  o~csvLineOut(.array~of('schema','fixture'))
  o~csvLineOut(.array~of('TEST',kind))
  o~close
end
st=.FDCheckpointState~new
st~put('checkpoint_id','CKPT-TAMPER'); st~put('job_id','JOB-TAMPER'); st~put('migration_id','MIG-TAMPER'); st~put('output_base_name','analysis'); st~put('event_class','')
checkpoint=q||'/source/checkpoint.tsv'; st~write(checkpoint)
bundle=q||'/source/checkpoint.fdmjob.tar'
digest=.FDMigrationBundle~create(bundle,checkpoint,prefix,1,'fixture.mp4','REQ-TAMPER','MIG-TAMPER','JOB-TAMPER','CKPT-TAMPER')
if \digest~startsWith('sha256:') then call fail 'digest format'
/* Corrupt the byte object after the digest has been issued. */
address system "printf 'X' >> "||quote(bundle)
if rc<>0 then call fail 'could not tamper fixture'
caught=.false
signal on syntax name expectedFailure
x=.FDMigrationBundle~materialize(bundle,q||'/destination/analysis',q||'/destination/state',digest,'CKPT-TAMPER')
signal off syntax
call fail 'tampered migration bundle was accepted'
expectedFailure:
  signal off syntax
  caught=.true
  say 'PASS migration bundle tamper rejected at digest-bound materialization code='||condition('C')
  exit 0

quote: procedure
  parse arg s
  return "'"||s~changestr("'","'\\''")||"'"
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
