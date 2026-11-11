/* Native ooRexx 1080p sky scan from two true MP4 H.264 files.
 * No filename extension inference, no ffmpeg process, no Python image analysis.
 * A compact bright point is never automatically a star.
 */
numeric digits 30
root='/mnt/data'; out='/mnt/data/moonsault_20261110/'
files=.array~of('WebcamSydney 1 Live Stream of Harbour 247 4K(1).mp4', -
                'WebcamSydney 1 Live Stream of Harbour 247 4K(2).mp4')
times=.array~of(5,30,60)
ignore=charout(out||'all_bright_points.tsv','clip'||'09'x||'sec'||'09'x||'x'||'09'x||'y'||'09'x||'contrast'||'09'x||'peak'||'0a'x,1)
all=.array~new;clock=.array~new;alignments=.array~new
refLum='';obs=.array~new
do i=1 to files~items
 fsource=.MediaLocalByteSource~new(root||'/'||files[i])
 mp4=.MediaMp4AvcAccess~new(fsource)
 do j=1 to times~items
    sec=times[j]
    frame=mp4~frameAt(sec*90000,2097152,200)
    if frame==.nil then do
     say 'FRAME MISS' i sec
     exit 31
    end
    lum=.MediaRasterPlanes~luma(frame~pixels,frame~width,frame~height,3)
    points=.MoonsaultStillPointScan~scan(lum,1920,1080,45,1875,25,375,8,2000)
    all~append(points)
    if refLum='' then do
      refLum=lum
      reg=.array~of(0,0,0)
    end
    else reg=.MoonsaultStillPointScan~register(refLum,lum,1920,1080)
    alignments~append(reg)
    seconds=(i-1)*275+sec
    clock~append(seconds)
    say 'POINTS clip' i 't='sec 'count='points~items 'reg dx/dy='reg[1] reg[2] 'MAE='format(reg[3],,2)
    do p over points
     line=i||'09'x||sec||'09'x||p['X']||'09'x||p['Y']||'09'x|| -
       format(p['CONTRAST'],,2)||'09'x||p['PEAK']||'0a'x
     ignore=charout(out||'all_bright_points.tsv',line)
    end
    /* 1920x1080 sky-only luma is 2MB, do not keep every RGB buffer. */
 end
 fsource~close
end
ignore=stream(out||'all_bright_points.tsv','C','CLOSE')
/* The clips contain non-contiguous webcam timestamps; do not interpolate gap. */
return 0
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaLocalByteSource.cls'
::requires '../../oorexx_media_object_access_v0.1-dev1/src/MediaMp4AvcAccess.cls'
::requires '../src/MoonsaultStillPointScan.cls'