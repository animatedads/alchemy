numeric digits 30
parse arg root .
if root='' then root='/mnt/data'
root=root||'/'
a=.MediaLocalByteSource~new(root||'1000069592.jpg')
b=.MediaLocalByteSource~new(root||'1000069593.jpg')
f1=.MediaJpegFile~new(a)~decode
f2=.MediaJpegFile~new(b)~decode
fit=.MediaRasterOps~estimateTranslation(f1,f2,300,300,900,200,4)
say 'SYDNEY JPEG skyline register' fit['DX'] fit['DY'] -
    'scorePPM' fit['SCORE_PPM'] 'samples' fit['LANDMARK_SAMPLES']
say 'PASS landmark-only registration; no sky points used'
ignore=a~close;ignore=b~close
exit 0
::requires '../src/MediaLocalByteSource.cls'
::requires '../src/MediaJpegFile.cls'
::requires '../src/MediaRasterOps.cls'