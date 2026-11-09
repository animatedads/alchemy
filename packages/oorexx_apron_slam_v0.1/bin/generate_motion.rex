/* Apron SLAM — known glyph motion/exposure path CSV. No OCR or codec used.
 * The camera/3D geometry belongs to ooRexx. A renderer consumes this CSV.
 * Orientation table below is a fixture of independent known sin/cos values;
 * normal runtime orientation is through ApronOrientation~fromYawDegrees using Maths.
 */
numeric digits 30
parse arg outputFile .
if outputFile='' then outputFile='../results/glyph_motion.csv'
opened=stream(outputFile,'C','OPEN WRITE REPLACE')
if left(opened,5)<>"READY" then do; say 'Cannot open output' opened; exit 2; end
header='glyph,speed_kmh,yaw_deg,range_m,fps,shutter_us,sample_index,source_time_us,' || -
       'u0,v0,u1,v1,u2,v2,u3,v3' || '0a'x
call charout outputFile,header
cam=.ApronCamera~new(1920,1080,1200,1200,1.5)
glyphs='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
speeds=.array~of(0,20,40,60,80)
angles=.array~of(0,30,60)
sines=.array~of(0,.5,'0.86602540378443864676372317075294')
cosines=.array~of(1,'0.86602540378443864676372317075294',.5)
shutters=.array~of(1000,10000)
ranges=.array~of(8,12,20)
fpsValues=.array~of(25,50)
scenarios=0;records=0
/* Source frame 1 is well after the first shutter opens, for every fixture. */
frameIndex=1
samples=9
/* Keep the font family as provenance metadata only. Never pack/distribute TTF. */
do a=1 to angles~items
  orient=.ApronOrientation~new(angles[a],sines[a],cosines[a])
  car=.ApronCarBox~new(orient)
  do distance over ranges
    do rate over fpsValues
      do speed over speeds
        do shutter over shutters
          drive=.ApronDriveBy~new(cam,car,-1,distance,speed,rate,shutter)
          do gi=1 to glyphs~length
            glyph=substr(glyphs,gi,1)
            glyphWidth=.05
            if glyph='I' | glyph='1' then glyphWidth=.011
            scenarios=scenarios+1
            do si=0 to samples-1
              poly=drive~exposureSample(frameIndex,si,samples,glyphWidth)
              tUs=(frameIndex/rate+((si/(samples-1))-.5)*shutter/1000000)*1000000
              record=glyph||','||speed||','||angles[a]||','||distance||','||rate||','||shutter||','||si||','||format(tUs,,3)
              do vertex over poly
                record=record||','||format(vertex[1],,6)||','||format(vertex[2],,6)
              end
              ignore=charout(outputFile,record||'0a'x)
              records=records+1
            end
          end
        end
      end
    end
  end
end
ignore=stream(outputFile,'C','CLOSE')
say 'Apron SLAM projection complete:' scenarios 'scenarios,' records 'sub-exposure records'
exit 0
::requires '../src/ApronGeometry.cls'