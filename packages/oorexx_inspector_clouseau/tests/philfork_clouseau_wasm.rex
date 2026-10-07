/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2014 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                                        */
/*                                                                            */
/* Redistribution and use in source and binary forms, with or                 */
/* without modification, are permitted provided that the following            */
/* conditions are met:                                                        */
/*                                                                            */
/* Redistributions of source code must retain the above copyright             */
/* notice, this list of conditions and the following disclaimer.              */
/* Redistributions in binary form must reproduce the above copyright          */
/* notice, this list of conditions and the following disclaimer in            */
/* the documentation and/or other materials provided with the distribution.   */
/*                                                                            */
/* Neither the name of Rexx Language Association nor the names                */
/* of its contributors may be used to endorse or promote products             */
/* derived from this software without specific prior written permission.      */
/*                                                                            */
/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        */
/* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT          */
/* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,      */
/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   */
/* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,        */
/* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY     */
/* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING    */
/* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         */
/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               */
/*                                                                            */
/*----------------------------------------------------------------------------*/
/* Inspector Clouseau qualification variant of samples/philfork.rex.          */
/* The philosopher/fork logic remains the ooRexx sample logic; the added      */
/* Inspector block observes the live object graph while START/GUARD methods   */
/* are active and validates that PHIL and FORK instances are visible.         */
/*----------------------------------------------------------------------------*/

arg parms
if parms = '' then parms = '1 1 any 1'
parse var parms psleep peat pside prepeats
T.eat = peat
T.sleep = psleep
T.veat = trunc(peat / 2)
T.vsleep = trunc(psleep / 2)
if      pside = 'L' then T.side = 100
else if pside = 'R' then T.side = 0
                    else T.side = 50
T.repeats = prepeats

f1 = .fork~new(1)
f2 = .fork~new(2)
f3 = .fork~new(3)
f4 = .fork~new(4)
f5 = .fork~new(5)
p1 = .phil~new(1,f5,f1)
p2 = .phil~new(2,f1,f2)
p3 = .phil~new(3,f2,f3)
p4 = .phil~new(4,f3,f4)
p5 = .phil~new(5,f4,f5)

inspector = .InspectorClouseau~new
inspector~enableProbes(.false)
inspector~dontFollowPackage('REXX')
inspector~reportCollectionSizes(.true)
inspector~reportVariable('*')
inspector~reportInheritanceMap(.true)
inspector~suppressInternalClassMethods(.true)
/* addRoot avoids Inspector's optional automatic environment roots, keeping
   this qualification focused on the ten application objects. */
inspector~addPackage(.context~package)
inspector~addRoot('p1',p1)
inspector~addRoot('p2',p2)
inspector~addRoot('p3',p3)
inspector~addRoot('p4',p4)
inspector~addRoot('p5',p5)
inspector~addRoot('f1',f1)
inspector~addRoot('f2',f2)
inspector~addRoot('f3',f3)
inspector~addRoot('f4',f4)
inspector~addRoot('f5',f5)

m1 = p1~start('run',T.)
m2 = p2~start('run',T.)
m3 = p3~start('run',T.)
m4 = p4~start('run',T.)
m5 = p5~start('run',T.)

/* Observe while the concurrent methods are alive.  Probes remain disabled:
   concurrent qualification is observational and does not mutate method tables. */
call SysSleep 0.2
snapshot = inspector~snapshot
data = snapshot~asDirectory

philCount = 0
forkCount = 0
probeCount = 0
do rec over data~at('objects')
  cname = rec~at('class')
  if cname = 'PHIL' then philCount = philCount + 1
  if cname = 'FORK' then forkCount = forkCount + 1
  if rec~hasIndex('probe') then probeCount = probeCount + 1
end

say 'CLOUSEAU schema='data~at('schema')
say 'CLOUSEAU objects='data~at('objects')~items 'phil='philCount 'fork='forkCount 'probed='probeCount

m1~result
m2~result
m3~result
m4~result
m5~result

if philCount < 5 then do
  say 'FAIL Inspector did not observe all philosopher objects'
  exit 11
end
if forkCount < 5 then do
  say 'FAIL Inspector did not observe all fork objects'
  exit 12
end
say 'PASS Inspector Clouseau dining philosophers WASM qualification'
return 0

::class phil

::method init
   expose num rfork lfork out
   use arg num, rfork, lfork
   out = ' '~copies(15*num-14)

::method run
   expose num rfork lfork out
   use arg T.
   x = random(1,100,time('S')*num)
   say out 'Philosopher-'num
   do i=1 to T.repeats
      stime = random(T.sleep-T.vsleep,T.sleep+T.vsleep)
      say out 'Sleep-'stime
      rc=SysSleep(stime)
      say out 'Wait'
      if random(1,100) < T.side then do
         lfork~pickup(1,'left',num)
         rfork~pickup(2,'right',num)
      end
      else do
         rfork~pickup(1,'right',num)
         lfork~pickup(2,'left',num)
      end
      etime = random(T.eat-T.veat,T.eat+T.veat)
      say out 'Eat-'etime
      rc=SysSleep(etime)
      lfork~laydown(num)
      rfork~laydown(num)
   end
   say out 'Done'
   return 1

::class fork

::method init
   expose used
   used = 0

::method pickup
   expose used
   guard on when used = 0
   used = 1

::method laydown unguarded
   expose used
   used = 0

::requires 'InspectorClouseau.cls'
