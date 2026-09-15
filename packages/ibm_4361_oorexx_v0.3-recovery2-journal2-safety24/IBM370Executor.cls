::options digits 30

/* IBM370Executor.cls - demand-driven System/370 instruction executor.
 *
 * Unsupported instructions are atomic: supportsInstruction() is checked before
 * PSW/CPU state is changed.  Permanent OPxx methods are ordinary class methods;
 * an object-scope OPxx installed with setMethod() therefore overrides them and
 * can be trialled through the journal recovery path without a process restart.
 */
::class IBM370Executor public

::method init
  expose machine cpu storage channels clock lastStatus lastIA lastOpcode lastInstruction nativeOps
  use strict arg machineObject
  machine=machineObject; cpu=machine~cpu; storage=machine~storage
  channels=machine~channels; clock=machine~clock
  lastStatus="READY"; lastIA=-1; lastOpcode=-1; lastInstruction=""
  nativeOps="04|05|06|07|08|0A|10|11|12|13|14|15|16|17|18|19|1A|1B|1C|1D|1E|1F|28|35|40|41|42|43|44|45|46|47|48|49|4A|4E|50|54|55|56|57|58|59|5A|5B|5E|5F|60|68|80|82|87|88|89|8A|8B|8D|90|91|92|94|95|96|98|9B|9C|9D|9F|AF|B2|BF|D2|D4|D5|D6|D7|F2|F3|"

::method lastStatus; expose lastStatus; return lastStatus
::method lastIA; expose lastIA; return lastIA
::method lastOpcode; expose lastOpcode; return lastOpcode
::method lastInstruction; expose lastInstruction; return lastInstruction

/* Public object-scope trial seam.  This keeps journal/live-recovery optional:
 * the core executor has no dependency on JournalPointedState, but a recovery
 * coordinator can install OPxx#OBJECT code and then rewind machine state. */
::method installLiveMethod
  use strict arg methodName,source
  self~setMethod(methodName,source,"OBJECT")
  return .true

/* Remove one object-scope executable hypothesis.  Like installation and
 * replacement, method removal is intentionally outside journalled machine
 * state: rewinding CPU/RAM/device state must not resurrect withdrawn code. */
::method removeLiveMethod
  use strict arg methodName
  self~unsetMethod(methodName)
  return .true

/* Architectural-exception seam.  This is intentionally separate from OPxx
 * implementation coverage: an architecturally undefined opcode is a guest
 * program interruption, not a synthetic emulator instruction.  Safety14
 * promotes only the independently proved primary X'00' operation-exception
 * case; other unsupported opcodes remain archaeology boundaries until their
 * architectural classification is separately established. */
::method architecturalOperationException
  use strict arg raw
  if raw~length<2 then return .false
  op=raw~left(2)~translate
  /* Safety14 proved primary X'00'; safety16 proved X'FF'; safety17 proved
   * System/370 primary X'C4'; safety18 proved System/370 primary X'62';
   * safety21 proved System/370 primary X'65'; safety22 proves System/370
   * primary X'02'. Keep this as a positive allow-list so genuine emulator
   * coverage gaps remain atomic archaeology boundaries until separately
   * classified. */
  return op="00" | op="FF" | op="C4" | op="62" | op="65" | op="02"

::method architecturalSpecificationException
  /* Specification exceptions are instruction/operand validity checks, not
   * implementation-coverage decisions. Safety19 proves System/370 D (5D)
   * requires an even R1 register pair and that this check precedes divisor
   * fetch/divide processing. Safety23 proves System/370 STE (70) permits only
   * short-HFP register selectors 0,2,4,6; any other R1 raises specification
   * exception before normal STE implementation coverage is considered. */
  use strict arg raw
  if raw~length<4 then return .false
  op=raw~left(2)~translate
  r1=x2d(raw~substr(3,1))
  if op="5D" then return r1//2=1
  if op="70" then return r1<>0 & r1<>2 & r1<>4 & r1<>6
  return .false

::method programInterruptSpecification
  expose cpu storage
  use strict arg inst,ia,len
  /* Safety19 qualifies the BC-mode specification-exception path. */
  if cpu~psw~ecMode then raise syntax 40.900 array("EC-mode specification-exception program interruption not yet qualified",inst)
  cpu~psw~setInstructionLength(len)
  cpu~psw~setInstructionAddress((ia+len)//16777216)
  old=cpu~psw~rawWithInterruptionCode(6)
  base=cpu~prefix
  storage~storeHex((base+x2d("28"))//16777216,old)
  new=storage~fetchHex((base+x2d("68"))//16777216,8)
  cpu~psw~loadRawHex(new)
  return "OK"

::method programInterruptOperation
  expose cpu storage
  use strict arg inst,ia,len
  /* Safety14 qualifies the System/370 BC-mode operation-exception path.
   * EC-mode program-interruption side fields are deliberately not guessed. */
  if cpu~psw~ecMode then raise syntax 40.900 array("EC-mode operation-exception program interruption not yet qualified",inst)
  cpu~psw~setInstructionLength(len)
  cpu~psw~setInstructionAddress((ia+len)//16777216)
  old=cpu~psw~rawWithInterruptionCode(1)
  base=cpu~prefix
  storage~storeHex((base+x2d("28"))//16777216,old)
  new=storage~fetchHex((base+x2d("68"))//16777216,8)
  cpu~psw~loadRawHex(new)
  return "OK"

::method supportsInstruction
  expose nativeOps
  use strict arg raw
  if raw~length<4 then return 0
  op=raw~left(2)~translate
  /* B2 is a two-byte extended opcode family; only STCK (B205) is currently
   * implemented. */
  if op="B2" then return raw~length>=8 & raw~substr(3,2)~translate="05"
  if nativeOps~pos(op||"|")>0 then return 1
  /* Live trial methods are object-scope and therefore visible here without
   * rebuilding the permanent source table. */
  return self~hasMethod("OP"||op)

::method instructionLength
  use strict arg opcode
  op=opcode
  /* S/360/370 length encoding: top two opcode bits 00=>2, 01/10=>4, 11=>6. */
  top=op % 64
  if top=0 then return 2
  if top=1 | top=2 then return 4
  return 6

::method step
  expose cpu storage clock lastStatus lastIA lastOpcode lastInstruction
  ia=cpu~psw~instructionAddress
  raw=storage~fetchHex(ia,6)
  op=x2d(raw~left(2)); len=self~instructionLength(op)
  inst=raw~left(len*2)
  lastIA=ia; lastOpcode=op; lastInstruction=inst
  /* Operand-encoding specification checks have architectural priority over
   * implementation coverage.  Keeping this before supportsInstruction() also
   * preserves the check when a normal OP5D implementation is added later. */
  if self~architecturalSpecificationException(inst) then do
    ist=self~programInterruptSpecification(inst,ia,len)
    if ist="OK" then do
      cpu~noteInstruction
      lastStatus="OK"
      return "OK"
    end
    lastStatus=ist
    return ist
  end

  if \self~supportsInstruction(inst) then do
    /* An architecturally undefined instruction may be a guest-visible program
     * interruption rather than an emulator coverage gap.  Keep classification
     * and interruption handling outside the OPxx namespace so no synthetic
     * OP00 (or other undefined operation) is ever created. */
    if self~architecturalOperationException(inst) then do
      ist=self~programInterruptOperation(inst,ia,len)
      if ist="OK" then do
        cpu~noteInstruction
        lastStatus="OK"
        return "OK"
      end
      lastStatus=ist
      return ist
    end
    lastStatus="UNSUPPORTED"
    return "UNSUPPORTED"
  end

  /* EX executes a transiently modified target instruction, but exceptions
   * raised by that target are attributed to EX itself: use EX's IA and ILC in
   * the saved old PSW.  Perform this before the generic unsupported-target
   * boundary so an architecturally invalid target becomes a guest-visible
   * specification interruption rather than an emulator coverage gap. */
  if op=x2d("44") then do
    target=self~exTargetInstruction(inst)
    if self~architecturalSpecificationException(target) then do
      lastInstruction=inst||"->"||target
      ist=self~programInterruptSpecification(target,ia,len)
      if ist="OK" then do
        cpu~noteInstruction
        lastStatus="OK"
        return "OK"
      end
      lastStatus=ist
      return ist
    end
    if \self~supportsInstruction(target) then do
      lastStatus="UNSUPPORTED_EX_TARGET"
      lastInstruction=inst||"->"||target
      return "UNSUPPORTED"
    end
  end

  next=self~dispatch(inst,ia,0)
  /* LPSW replaces the complete current PSW.  Do not stamp the old
   * instruction's ILC/next-IA into the newly loaded PSW. */
  if op=x2d("82") then do
    cpu~noteInstruction
    lastStatus="OK"
    return "OK"
  end
  cpu~psw~setInstructionLength(len)
  cpu~psw~setInstructionAddress(next)
  cpu~noteInstruction
  lastStatus="OK"
  return "OK"

::method dispatch private
  use strict arg inst,ia,transient=0
  return self~sendWith("OP"||inst~left(2),.array~of(inst,ia,transient))

::method exTargetInstruction private
  expose cpu storage
  use strict arg inst
  r1=x2d(inst~substr(3,1)); x2=x2d(inst~substr(4,1)); b2=x2d(inst~substr(5,1)); d2=x2d(inst~substr(6,3))
  ea=self~eaRX(x2,b2,d2)
  target=storage~fetchHex(ea,6)
  orByte=cpu~gprFast(r1)//256
  second=x2d(target~substr(3,2)); second=c2d(bitor(d2c(second),d2c(orByte)))
  return target~left(2)||d2x(second,2)||target~substr(5)

/* ---------- field/effective-address helpers ---------- */
::method rr private; use strict arg i; return .array~of(x2d(i~substr(3,1)),x2d(i~substr(4,1)))
::method eaRX private
  expose cpu
  use strict arg x,b,d
  a=d; if x<>0 then a=a+cpu~gprFast(x); if b<>0 then a=a+cpu~gprFast(b); return a//16777216
::method eaS private
  expose cpu
  use strict arg inst
  /* S format is OP, ignored/sub-op byte, then B2D2. */
  b=x2d(inst~substr(5,1)); d=x2d(inst~substr(6,3)); a=d; if b<>0 then a=a+cpu~gprFast(b); return a//16777216
::method rxFields private
  use strict arg i
  r=x2d(i~substr(3,1)); x=x2d(i~substr(4,1)); b=x2d(i~substr(5,1)); d=x2d(i~substr(6,3)); return .array~of(r,x,b,d)
::method rsFields private
  use strict arg i
  r1=x2d(i~substr(3,1)); r3=x2d(i~substr(4,1)); b=x2d(i~substr(5,1)); d=x2d(i~substr(6,3)); return .array~of(r1,r3,b,d)
::method siFields private
  use strict arg i
  imm=x2d(i~substr(3,2)); b=x2d(i~substr(5,1)); d=x2d(i~substr(6,3)); return .array~of(imm,b,d)
::method ssFields private
  use strict arg i
  l=x2d(i~substr(3,2))+1; b1=x2d(i~substr(5,1)); d1=x2d(i~substr(6,3)); b2=x2d(i~substr(9,1)); d2=x2d(i~substr(10,3)); return .array~of(l,b1,d1,b2,d2)
::method eaBD private
  expose cpu
  use strict arg b,d
  a=d; if b<>0 then a=a+cpu~gprFast(b); return a//16777216
::method u32 private; use strict arg v; v=v//4294967296; if v<0 then v=v+4294967296; return v
::method s32 private; use strict arg v; v=self~u32(v); if v>=2147483648 then return v-4294967296; return v
::method s16 private; use strict arg v; v=v//65536; if v>=32768 then return v-65536; return v
::method ccSigned private
  expose cpu
  use strict arg v
  if v=0 then cc=0; else if v<0 then cc=1; else cc=2
  cpu~psw~setConditionCode(cc); return cc
::method ccLogical private
  expose cpu
  use strict arg v
  if v=0 then cc=0; else cc=1
  cpu~psw~setConditionCode(cc); return cc
::method branchMask private
  expose cpu
  use strict arg mask
  cc=cpu~psw~conditionCode; bit=8%(2**cc); return c2d(bitand(d2c(mask),d2c(bit)))<>0
::method addSigned private
  expose cpu
  use strict arg a,b
  sa=self~s32(a); sb=self~s32(b); exact=sa+sb; overflow=(exact>2147483647 | exact< -2147483648)
  r=self~u32(exact); sr=self~s32(r)
  if overflow then cc=3; else if sr=0 then cc=0; else if sr<0 then cc=1; else cc=2
  cpu~psw~setConditionCode(cc); return r
::method subSigned private
  use strict arg a,b
  return self~addSigned(a,-self~s32(b))

/* ---------- RR ---------- */
::method OP04; expose cpu; use strict arg i,ia,t=0; r=self~rr(i)[1]; v=cpu~gprFast(r); byte=(v%16777216)//256; cpu~psw~setConditionCode((byte%16)%4); cpu~psw~setProgramMask(byte//16); return ia+2
::method OP05
  expose cpu; use strict arg i,ia,t=0; f=self~rr(i); r1=f[1]; r2=f[2]; target=0; if r2<>0 then target=cpu~gprFast(r2)//16777216
  high=64 + cpu~psw~conditionCode*16 + cpu~psw~programMask; cpu~setGprFast(r1,high*16777216+((ia+2)//16777216)); if r2<>0 then return target; return ia+2
::method OP06; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); r1=f[1]; r2=f[2]; v=self~u32(cpu~gprFast(r1)-1); cpu~setGprFast(r1,v); if v<>0 & r2<>0 then return cpu~gprFast(r2)//16777216; return ia+2
::method OP07; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); if f[2]<>0 & self~branchMask(f[1]) then return cpu~gprFast(f[2])//16777216; return ia+2
::method OP08
  expose cpu storage; use strict arg i,ia,t=0; f=self~rr(i); r1=f[1]; r2=f[2]
  if cpu~psw~problemState then raise syntax 40.900 array("SSK privileged-operation exception")
  spec=cpu~gprFast(r2); if spec//16<>0 then raise syntax 40.900 array("SSK specification exception",d2x(spec,8))
  addr=(spec%16777216)//2048*2048; key=(cpu~gprFast(r1)%16777216)//16777216
  storage~setStorageKeyRaw(addr,key); return ia+2
::method OP0A
  expose cpu storage; use strict arg i,ia,t=0; svc=x2d(i~substr(3,2)); old=cpu~psw~rawWithInterruptionCode(svc); cpu~psw~setInstructionLength(2); cpu~psw~setInstructionAddress(ia+2); storage~storeHex(x2d("20"),old); return x2d(storage~fetchHex(x2d("60"),8)~substr(11,6))
::method OP10; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); v=self~s32(cpu~gprFast(f[2])); if v=-2147483648 then r=2147483648; else r=self~u32(abs(v)); cpu~setGprFast(f[1],r); self~ccSigned(self~s32(r)); return ia+2
::method OP11; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); v=self~s32(cpu~gprFast(f[2])); if v>0 then v=-v; cpu~setGprFast(f[1],self~u32(v)); self~ccSigned(v); return ia+2
::method OP12; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); cpu~setGprFast(f[1],cpu~gprFast(f[2])); self~ccSigned(self~s32(cpu~gprFast(f[1]))); return ia+2
::method OP13
  /* LCR forms the signed two's-complement of R2 and sets CC from the result.
   * X'80000000' cannot be complemented in 32 signed bits: the result remains
   * X'80000000' and CC=3.  If fixed-point overflow is masked on, the required
   * program-interruption path is not yet qualified and therefore fails closed. */
  expose cpu
  use strict arg i,ia,t=0
  f=self~rr(i)
  v=self~s32(cpu~gprFast(f[2]))
  if v=-2147483648 then do
    if cpu~psw~programMask>=8 then raise syntax 40.900 array("LCR fixed-point-overflow interruption path not yet implemented")
    cpu~setGprFast(f[1],2147483648)
    cpu~psw~setConditionCode(3)
  end
  else do
    r=-v
    cpu~setGprFast(f[1],self~u32(r))
    self~ccSigned(r)
  end
  return ia+2
::method OP14
  /* NR logically ANDs the two 32-bit general-register operands.  The second
   * register is unchanged; CC is zero-result/nonzero-result only. */
  expose cpu
  use strict arg i,ia,t=0
  f=self~rr(i)
  v=c2d(bitand(d2c(self~s32(cpu~gprFast(f[1])),4),d2c(self~s32(cpu~gprFast(f[2])),4)))
  cpu~setGprFast(f[1],v)
  self~ccLogical(v)
  return ia+2
::method OP15; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); a=cpu~gprFast(f[1]); b=cpu~gprFast(f[2]); if a=b then cc=0; else if a<b then cc=1; else cc=2; cpu~psw~setConditionCode(cc); return ia+2
::method OP16; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); v=c2d(bitor(d2c(cpu~gprFast(f[1]),4),d2c(cpu~gprFast(f[2]),4))); cpu~setGprFast(f[1],v); self~ccLogical(v); return ia+2
::method OP17; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); v=c2d(bitxor(d2c(cpu~gprFast(f[1]),4),d2c(cpu~gprFast(f[2]),4))); cpu~setGprFast(f[1],v); self~ccLogical(v); return ia+2
::method OP18; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); cpu~setGprFast(f[1],cpu~gprFast(f[2])); return ia+2
::method OP19; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); a=self~s32(cpu~gprFast(f[1])); b=self~s32(cpu~gprFast(f[2])); if a=b then cc=0; else if a<b then cc=1; else cc=2; cpu~psw~setConditionCode(cc); return ia+2
::method OP1A; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); cpu~setGprFast(f[1],self~addSigned(cpu~gprFast(f[1]),cpu~gprFast(f[2]))); return ia+2
::method OP1B; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); cpu~setGprFast(f[1],self~subSigned(cpu~gprFast(f[1]),cpu~gprFast(f[2]))); return ia+2
::method OP1C
  expose cpu; use strict arg i,ia,t=0; f=self~rr(i); r1=f[1]; r2=f[2]; if r1//2<>0 then raise syntax 40.900 array("MR requires even R1",r1)
  prod=self~s32(cpu~gprFast(r1+1))*self~s32(cpu~gprFast(r2)); u=prod//18446744073709551616; if u<0 then u=u+18446744073709551616
  cpu~setGprFast(r1,u%4294967296); cpu~setGprFast(r1+1,u//4294967296); return ia+2
::method OP1D
  expose cpu; use strict arg i,ia,t=0; f=self~rr(i); r1=f[1]; r2=f[2]; if r1//2<>0 then raise syntax 40.900 array("DR requires even R1",r1)
  divisor=self~s32(cpu~gprFast(r2)); if divisor=0 then raise syntax 40.900 array("DR divide exception")
  hi=cpu~gprFast(r1); lo=cpu~gprFast(r1+1); dividend=hi*4294967296+lo; if hi>=2147483648 then dividend=dividend-18446744073709551616
  q=trunc(dividend/divisor); rem=dividend-q*divisor; if q>2147483647 | q< -2147483648 then raise syntax 40.900 array("DR quotient overflow")
  cpu~setGprFast(r1,self~u32(rem)); cpu~setGprFast(r1+1,self~u32(q)); return ia+2
::method OP1E
  /* ALR adds two unsigned 32-bit general-register operands.  The low 32
   * bits are stored in R1; CC encodes carry-out and zero exactly as AL. */
  expose cpu
  use strict arg i,ia,t=0
  f=self~rr(i)
  a=cpu~gprFast(f[1])
  b=cpu~gprFast(f[2])
  exact=a+b
  carry=(exact>=4294967296)
  v=exact//4294967296
  cpu~setGprFast(f[1],v)
  if carry then do
    if v=0 then cc=2; else cc=3
  end
  else do
    if v=0 then cc=0; else cc=1
  end
  cpu~psw~setConditionCode(cc)
  return ia+2
::method OP1F
  expose cpu; use strict arg i,ia,t=0; f=self~rr(i); a=cpu~gprFast(f[1]); b=cpu~gprFast(f[2]); carry=(a>=b); r=self~u32(a-b); cpu~setGprFast(f[1],r)
  if carry then do; if r=0 then cc=2; else cc=3; end; else do; if r=0 then cc=0; else cc=1; end
  cpu~psw~setConditionCode(cc); return ia+2
::method OP28; expose cpu; use strict arg i,ia,t=0; f=self~rr(i); if f[1]//2<>0 | f[2]//2<>0 then raise syntax 40.900 array("LDR invalid floating register"); cpu~setFprHex(f[1]%2,cpu~fprHex(f[2]%2)); return ia+2
::method OP35
  expose cpu; use strict arg i,ia,t=0; f=self~rr(i); if f[1]//2<>0 | f[2]//2<>0 then raise syntax 40.900 array("LRER invalid floating register")
  src=cpu~fprHex(f[2]%2); hi=x2d(src~left(8)); lo=x2d(src~right(8)); rounded=hi
  /* IBM short rounding: add x'80000000' to discarded low fraction; if carry,
   * propagate into high word.  Destination low word is preserved. */
  if lo>=x2d("80000000") then rounded=(rounded+1)//4294967296
  old=cpu~fprHex(f[1]%2); cpu~setFprHex(f[1]%2,d2x(rounded,8)||old~right(8)); return ia+2

/* ---------- RX ---------- */
::method OP40; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); ea=self~eaRX(f[2],f[3],f[4]); storage~storeHex(ea,d2x(cpu~gprFast(f[1])//65536,4)); return ia+4
::method OP41; expose cpu; use strict arg i,ia,t=0; f=self~rxFields(i); cpu~setGprFast(f[1],self~eaRX(f[2],f[3],f[4])); return ia+4
::method OP42; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); storage~storeHex(self~eaRX(f[2],f[3],f[4]),d2x(cpu~gprFast(f[1])//256,2)); return ia+4
::method OP43; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); b=x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),1)); cpu~setGprFast(f[1],(cpu~gprFast(f[1])%256)*256+b); return ia+4
::method OP44
  /* EX executes the target instruction transiently, but normal sequencing
   * resumes after EX itself.  Only a target which actually changes control
   * flow may override that return address.  The target bytes in storage are
   * never modified. */
  use strict arg i,ia,t=0
  target=self~exTargetInstruction(i)
  targetAddr=self~eaRX(x2d(i~substr(4,1)),x2d(i~substr(5,1)),x2d(i~substr(6,3)))
  targetOp=x2d(target~left(2))
  if targetOp=x2d("44") then raise syntax 40.900 array("EX execute exception",d2x(targetAddr,6))
  targetLen=self~instructionLength(targetOp)
  targetNext=self~dispatch(target,targetAddr,1)
  if targetNext=(targetAddr+targetLen)//16777216 then return (ia+4)//16777216
  return targetNext
::method OP45
  /* BAL address generation uses the pre-instruction GPR contents.  Compute
   * the RX effective address before writing R1 because R1 may alias X2/B2. */
  expose cpu
  use strict arg i,ia,t=0
  f=self~rxFields(i)
  target=self~eaRX(f[2],f[3],f[4])
  high=128+cpu~psw~conditionCode*16+cpu~psw~programMask
  cpu~setGprFast(f[1],high*16777216+((ia+4)//16777216))
  return target
::method OP46; expose cpu; use strict arg i,ia,t=0; f=self~rxFields(i); v=self~u32(cpu~gprFast(f[1])-1); cpu~setGprFast(f[1],v); if v<>0 then return self~eaRX(f[2],f[3],f[4]); return ia+4
::method OP47; use strict arg i,ia,t=0; f=self~rxFields(i); if self~branchMask(f[1]) then return self~eaRX(f[2],f[3],f[4]); return ia+4
::method OP48; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); v=self~s16(x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),2))); cpu~setGprFast(f[1],self~u32(v)); return ia+4
::method OP49; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); a=self~s32(cpu~gprFast(f[1])); b=self~s16(x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),2))); if a=b then cc=0; else if a<b then cc=1; else cc=2; cpu~psw~setConditionCode(cc); return ia+4
::method OP4A; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); b=self~s16(x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),2))); cpu~setGprFast(f[1],self~addSigned(cpu~gprFast(f[1]),b)); return ia+4
::method OP4E
  /* CVD converts the signed 32-bit GPR value to an 8-byte packed-decimal
   * operand.  The low-order sign nibble is C for non-negative values and D
   * for negative values; the condition code is unchanged. */
  expose cpu storage
  use strict arg i,ia,t=0
  f=self~rxFields(i)
  ea=self~eaRX(f[2],f[3],f[4])
  v=self~s32(cpu~gprFast(f[1]))
  sign="C"
  if v<0 then do
    sign="D"
    v=-v
  end
  packed=v~string~right(15,"0")||sign
  storage~storeHex(ea,packed)
  return ia+4
::method OP50; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); storage~storeHex(self~eaRX(f[2],f[3],f[4]),d2x(cpu~gprFast(f[1]),8)); return ia+4
::method OP54; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); v=c2d(bitand(d2c(cpu~gprFast(f[1]),4),x2c(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),4)))); cpu~setGprFast(f[1],v); self~ccLogical(v); return ia+4
::method OP55; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); a=cpu~gprFast(f[1]); b=x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),4)); if a=b then cc=0; else if a<b then cc=1; else cc=2; cpu~psw~setConditionCode(cc); return ia+4
::method OP56
  /* O logically ORs the 32-bit storage operand into R1.  Storage is read-only;
   * CC0 denotes a zero result and CC1 a nonzero result. */
  expose cpu storage
  use strict arg i,ia,t=0
  f=self~rxFields(i)
  ea=self~eaRX(f[2],f[3],f[4])
  v=c2d(bitor(d2c(cpu~gprFast(f[1]),4),x2c(storage~fetchHex(ea,4))))
  cpu~setGprFast(f[1],v)
  self~ccLogical(v)
  return ia+4
::method OP57; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); v=c2d(bitxor(d2c(cpu~gprFast(f[1]),4),x2c(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),4)))); cpu~setGprFast(f[1],v); self~ccLogical(v); return ia+4
::method OP58; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); cpu~setGprFast(f[1],x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),4))); return ia+4
::method OP59; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); a=self~s32(cpu~gprFast(f[1])); b=self~s32(x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),4))); if a=b then cc=0; else if a<b then cc=1; else cc=2; cpu~psw~setConditionCode(cc); return ia+4
::method OP5A; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); cpu~setGprFast(f[1],self~addSigned(cpu~gprFast(f[1]),x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),4)))); return ia+4
::method OP5B; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); cpu~setGprFast(f[1],self~subSigned(cpu~gprFast(f[1]),x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),4)))); return ia+4
::method OP5E
  /* AL adds two unsigned 32-bit fullwords.  The low 32 bits are stored in
   * R1; CC encodes result-zero and carry-out independently:
   *   0=no carry/zero, 1=no carry/nonzero, 2=carry/zero, 3=carry/nonzero. */
  expose cpu storage
  use strict arg i,ia,t=0
  f=self~rxFields(i)
  ea=self~eaRX(f[2],f[3],f[4])
  a=cpu~gprFast(f[1])
  b=x2d(storage~fetchHex(ea,4))
  exact=a+b
  carry=(exact>=4294967296)
  v=exact//4294967296
  cpu~setGprFast(f[1],v)
  if carry then do
    if v=0 then cc=2; else cc=3
  end
  else do
    if v=0 then cc=0; else cc=1
  end
  cpu~psw~setConditionCode(cc)
  return ia+4
::method OP5F
  expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); a=cpu~gprFast(f[1]); b=x2d(storage~fetchHex(self~eaRX(f[2],f[3],f[4]),4)); carry=(a>=b); r=self~u32(a-b); cpu~setGprFast(f[1],r)
  if carry then do; if r=0 then cc=2; else cc=3; end; else do; if r=0 then cc=0; else cc=1; end; cpu~psw~setConditionCode(cc); return ia+4
::method OP60; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); if f[1]//2<>0 then raise syntax 40.900 array("STD invalid floating register"); storage~storeHex(self~eaRX(f[2],f[3],f[4]),cpu~fprHex(f[1]%2)); return ia+4
::method OP68; expose cpu storage; use strict arg i,ia,t=0; f=self~rxFields(i); if f[1]//2<>0 then raise syntax 40.900 array("LD invalid floating register"); cpu~setFprHex(f[1]%2,storage~fetchHex(self~eaRX(f[2],f[3],f[4]),8)); return ia+4

/* ---------- S/RS/SI ---------- */
::method OP80; expose cpu storage; use strict arg i,ia,t=0; if cpu~psw~problemState then raise syntax 40.900 array("SSM privileged-operation exception"); ea=self~eaS(i); cpu~psw~setSystemMask(x2d(storage~fetchHex(ea,1))); return ia+4
::method OP82; expose cpu storage; use strict arg i,ia,t=0; if cpu~psw~problemState then raise syntax 40.900 array("LPSW privileged-operation exception"); ea=self~eaS(i); cpu~psw~loadRawHex(storage~fetchHex(ea,8)); return cpu~psw~instructionAddress
::method OP87
  expose cpu; use strict arg i,ia,t=0; f=self~rsFields(i); r1=f[1]; r3=f[2]; inc=cpu~gprFast(r3); lim=cpu~gprFast((r3+1)//16); v=self~u32(cpu~gprFast(r1)+inc); cpu~setGprFast(r1,v); if self~s32(v)<=self~s32(lim) then return self~eaBD(f[3],f[4]); return ia+4
::method OP88; expose cpu; use strict arg i,ia,t=0; f=self~rsFields(i); n=self~eaBD(f[3],f[4])//64; v=cpu~gprFast(f[1]); if n>=32 then v=0; else v=v%(2**n); cpu~setGprFast(f[1],v); return ia+4
::method OP89; expose cpu; use strict arg i,ia,t=0; f=self~rsFields(i); n=self~eaBD(f[3],f[4])//64; v=cpu~gprFast(f[1]); if n>=32 then v=0; else v=self~u32(v*(2**n)); cpu~setGprFast(f[1],v); return ia+4
::method OP8A
  expose cpu
  use strict arg i,ia,t=0
  f=self~rsFields(i)
  r=f[1]
  n=self~eaBD(f[3],f[4])//64
  old=cpu~gprFast(r)
  if n=0 then v=old
  else if n>30 then do
    if old>=2147483648 then v=4294967295
    else v=0
  end
  else do
    v=old%(2**n)
    if old>=2147483648 then v=v+(4294967296-(2**(32-n)))
  end
  cpu~setGprFast(r,v)
  self~ccSigned(self~s32(v))
  return ia+4
::method OP8B
  expose cpu
  use strict arg i, ia, t=0

  f = self~rsFields(i)
  r = f[1]
  n = self~eaBD(f[3], f[4]) // 64
  oldValue = cpu~gprFast(r)

  signBit = 0
  if oldValue >= 2147483648 then signBit = 2147483648
  numericPart = oldValue // 2147483648
  overflow = 0

  do j = 1 to n
    numericPart = self~u32(numericPart * 2)
    shiftedSign = 0
    if numericPart >= 2147483648 then shiftedSign = 2147483648
    if shiftedSign <> signBit then overflow = 1
  end

  resultValue = (numericPart // 2147483648) + signBit
  ignored = cpu~setGprFast(r, resultValue)

  cc = 0
  if overflow <> 0 then cc = 3
  else do
    signedResult = resultValue
    if signedResult >= 2147483648 then signedResult = signedResult - 4294967296
    if signedResult < 0 then cc = 1
    else if signedResult > 0 then cc = 2
  end

  ignored = cpu~psw~setConditionCode(cc)
  return ia + 4
::method OP8D
  expose cpu; use strict arg i,ia,t=0; f=self~rsFields(i); r=f[1]; if r//2<>0 then raise syntax 40.900 array("SLDL requires even register pair"); n=self~eaBD(f[3],f[4])//64; v=cpu~gprFast(r)*4294967296+cpu~gprFast(r+1); v=(v*(2**n))//18446744073709551616; cpu~setGprFast(r,v%4294967296); cpu~setGprFast(r+1,v//4294967296); return ia+4
::method OP90
  expose cpu storage; use strict arg i,ia,t=0; f=self~rsFields(i); r=f[1]; last=f[2]; ea=self~eaBD(f[3],f[4]); do forever; storage~storeHex(ea,d2x(cpu~gprFast(r),8)); ea=(ea+4)//16777216; if r=last then leave; r=(r+1)//16; end; return ia+4
::method OP91
  expose cpu storage; use strict arg i,ia,t=0; f=self~siFields(i); ea=self~eaBD(f[2],f[3]); v=x2d(storage~fetchHex(ea,1)); z=c2d(bitand(d2c(v),d2c(f[1]))); if z=0 then cc=0; else if z=f[1] then cc=3; else cc=1; cpu~psw~setConditionCode(cc); return ia+4
::method OP92; expose storage; use strict arg i,ia,t=0; f=self~siFields(i); storage~storeHex(self~eaBD(f[2],f[3]),d2x(f[1],2)); return ia+4
::method OP94; expose cpu storage; use strict arg i,ia,t=0; f=self~siFields(i); ea=self~eaBD(f[2],f[3]); v=c2d(bitand(x2c(storage~fetchHex(ea,1)),d2c(f[1]))); storage~storeHex(ea,d2x(v,2)); if v=0 then cpu~psw~setConditionCode(0); else cpu~psw~setConditionCode(1); return ia+4
::method OP95; expose cpu storage; use strict arg i,ia,t=0; f=self~siFields(i); v=x2d(storage~fetchHex(self~eaBD(f[2],f[3]),1)); if v=f[1] then cc=0; else if v<f[1] then cc=1; else cc=2; cpu~psw~setConditionCode(cc); return ia+4
::method OP96; expose cpu storage; use strict arg i,ia,t=0; f=self~siFields(i); ea=self~eaBD(f[2],f[3]); v=c2d(bitor(x2c(storage~fetchHex(ea,1)),d2c(f[1]))); storage~storeHex(ea,d2x(v,2)); if v=0 then cpu~psw~setConditionCode(0); else cpu~psw~setConditionCode(1); return ia+4
::method OP98
  expose cpu storage; use strict arg i,ia,t=0; f=self~rsFields(i); r=f[1]; last=f[2]; ea=self~eaBD(f[3],f[4]); do forever; cpu~setGprFast(r,x2d(storage~fetchHex(ea,4))); ea=(ea+4)//16777216; if r=last then leave; r=(r+1)//16; end; return ia+4
::method OP9B; expose cpu; use strict arg i,ia,t=0; cpu~psw~setConditionCode(0); return ia+4
::method OP9C
  expose cpu channels storage; use strict arg i,ia,t=0; dev=self~eaS(i)//65536; cc=channels~startIO(dev,storage); cpu~psw~setConditionCode(cc); return ia+4
::method OP9D
  expose cpu channels storage; use strict arg i,ia,t=0; dev=self~eaS(i)//65536; cc=channels~testIO(dev,storage); cpu~psw~setConditionCode(cc); return ia+4
::method OP9F
  expose cpu channels
  use strict arg i,ia,t=0
  cc=channels~testChannel(self~eaS(i))
  cpu~psw~setConditionCode(cc)
  return ia+4
::method OPAF
  expose cpu
  use strict arg i,ia,t=0
  f=self~siFields(i)
  imm=f[1]
  /* MC bits 8-11 are reserved and must be zero.  Bits 12-15 select
   * monitor class 0..15. */
  if imm % 16 <> 0 then raise syntax 40.900 array("MC specification exception: bits 8-11 must be zero")
  class=imm//16
  /* CR8 bits 16..31 correspond to classes 0..15.  Those are the low
   * sixteen numeric bits of our 32-bit CR value, with class 0 at X'8000'. */
  weight=32768 % (2**class)
  enabled=(cpu~cr(8) % weight)//2
  if enabled=0 then return ia+4
  /* The historical MVT boundary has CR8=0 and therefore exercises only the
   * architecturally defined no-op path.  Do not fabricate the monitor-event
   * program interruption until that path has its own exact-state proof. */
  raise syntax 40.900 array("MC monitor-event path not yet implemented",class,self~eaBD(f[2],f[3]))

::method OPB2
  expose storage clock; use strict arg i,ia,t=0; if i~substr(3,2)<>"05" then raise syntax 40.900 array("unsupported B2 extended opcode",i~substr(3,2)); ea=self~eaS("00"||i~substr(5,4)); storage~storeHex(ea,clock~todHex); return ia+4
::method OPBF
  expose cpu storage; use strict arg i,ia,t=0; f=self~rsFields(i); r=f[1]; mask=f[2]; ea=self~eaBD(f[3],f[4]); old=cpu~gprFast(r); inserted=old; src=storage~fetchHex(ea,4); pos=1
  do byte=0 to 3
    bit=8%(2**byte)
    if c2d(bitand(d2c(mask),d2c(bit)))<>0 then do
      shift=(3-byte)*8; base=(inserted%(2**(shift+8)))%(2**shift); new=x2d(src~substr(pos*2-1,2)); inserted=inserted-base*(2**shift)+new*(2**shift); pos=pos+1
    end
  end
  cpu~setGprFast(r,self~u32(inserted)); if pos=1 then cpu~psw~setConditionCode(0); else self~ccSigned(self~s32(inserted)); return ia+4

/* ---------- SS ---------- */
::method OPD2
  expose storage; use strict arg i,ia,t=0; f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); data=storage~fetchHex(a2,f[1]); storage~storeHex(a1,data); return ia+6
::method OPD4
  expose cpu storage
  use strict arg i,ia,t=0
  f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); nonzero=0
  /* NC is architecturally left-to-right.  Fetch and store one byte at a
   * time so destructive overlap observes bytes already changed by earlier
   * iterations.  Addresses wrap in the 24-bit System/370 address space. */
  do n=0 to f[1]-1
    d=(a1+n)//16777216; s=(a2+n)//16777216
    v=c2x(bitand(x2c(storage~fetchHex(d,1)),x2c(storage~fetchHex(s,1))))
    storage~storeHex(d,v)
    if v<>"00" then nonzero=1
  end
  cpu~psw~setConditionCode(nonzero)
  return ia+6
::method OPD5
  expose cpu storage; use strict arg i,ia,t=0; f=self~ssFields(i); a=storage~fetchHex(self~eaBD(f[2],f[3]),f[1]); b=storage~fetchHex(self~eaBD(f[4],f[5]),f[1]); if a=b then cc=0; else if a<b then cc=1; else cc=2; cpu~psw~setConditionCode(cc); return ia+6
::method OPD6
  expose cpu storage; use strict arg i,ia,t=0; f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); v=c2x(bitor(x2c(storage~fetchHex(a1,f[1])),x2c(storage~fetchHex(a2,f[1])))); storage~storeHex(a1,v); if verify(v,"0")=0 then cpu~psw~setConditionCode(0); else cpu~psw~setConditionCode(1); return ia+6
::method OPD7
  expose cpu storage; use strict arg i,ia,t=0; f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); v=c2x(bitxor(x2c(storage~fetchHex(a1,f[1])),x2c(storage~fetchHex(a2,f[1])))); storage~storeHex(a1,v); if verify(v,"0")=0 then cpu~psw~setConditionCode(0); else cpu~psw~setConditionCode(1); return ia+6
::method OPF2
  expose storage; use strict arg i,ia,t=0
  /* PACK converts zoned decimal to packed decimal.  Every source byte
   * contributes its low-order digit nibble.  The zone nibble of the
   * rightmost source byte becomes the packed sign nibble.  If the
   * destination is too short, high-order digits are truncated. */
  l1=x2d(i~substr(3,1))+1; l2=x2d(i~substr(4,1))+1; b1=x2d(i~substr(5,1)); d1=x2d(i~substr(6,3)); b2=x2d(i~substr(9,1)); d2=x2d(i~substr(10,3)); a1=self~eaBD(b1,d1); a2=self~eaBD(b2,d2)
  z=storage~fetchHex(a2,l2); digits=""; sign="C"
  do p=1 to z~length by 2
    byte=z~substr(p,2); digits=digits||byte~right(1)
    if p=z~length-1 then sign=byte~left(1)
  end
  need=l1*2-1
  if digits~length>need then digits=digits~right(need)
  else digits=digits~right(need,"0")
  packed=digits||sign
  storage~storeHex(a1,packed~right(l1*2))
  return ia+6
::method OPF3
  expose storage; use strict arg i,ia,t=0
  /* UNPK converts packed decimal to zoned decimal.  The low nibble of the
   * rightmost packed byte is the sign and becomes the zone nibble of the
   * rightmost destination byte.  Remaining destination zones are F.
   * High-order digits are truncated when the destination is shorter;
   * a longer destination is left-padded with zoned zeroes. */
  l1=x2d(i~substr(3,1))+1; l2=x2d(i~substr(4,1))+1
  b1=x2d(i~substr(5,1)); d1=x2d(i~substr(6,3)); b2=x2d(i~substr(9,1)); d2=x2d(i~substr(10,3))
  a1=self~eaBD(b1,d1); a2=self~eaBD(b2,d2)
  packed=storage~fetchHex(a2,l2)
  sign=packed~right(1)
  digits=packed~left(packed~length-1)
  if digits~length>l1 then digits=digits~right(l1)
  else digits=digits~right(l1,"0")
  zoned=""
  do p=1 to l1
    zone="F"
    if p=l1 then zone=sign
    zoned=zoned||zone||digits~substr(p,1)
  end
  storage~storeHex(a1,zoned)
  return ia+6

::requires "IBM370Architecture.cls"
::requires "IBM370IO.cls"
::method OPD1
  expose storage
  use strict arg i,ia,t=0
  f=self~ssFields(i)
  a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5])
  /* MVN is architecturally left-to-right.  Preserve the destination zone
   * nibble and copy the source numeric nibble one byte at a time so overlap
   * is destructive/sequential.  Addresses wrap in the 24-bit address space. */
  do n=0 to f[1]-1
    d=(a1+n)//16777216; s=(a2+n)//16777216
    db=storage~fetchHex(d,1); sb=storage~fetchHex(s,1)
    storage~storeHex(d,db~left(1)||sb~right(1))
  end
  return ia+6
