/* FDSqrt as it was before commit 3761f57c (fd_door_micro_motion v0.2-dev8 and -dev5), kept as a fixture so
 * SLAM can prove its old results false.  Code: ChatGPT (the door package).  Do not use: it stops too soon
 * above 1e6.  Copied verbatim from 3761f57c^:packages/fd_door_micro_motion_v0.2-dev8/src/FDDoorMicroMotion.cls
 */
::routine FDSqrt public
  use strict arg x
  if x<=0 then return 0
  guess=x; if guess<1 then guess=1
  do 14; guess=(guess+(x/guess))/2; end
  return guess
