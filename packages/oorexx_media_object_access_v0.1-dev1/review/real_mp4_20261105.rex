/* Real TP08 numeric MP4 sample table diagnostic, read-only original.
 * Author: Claude (Opus 5.5), 5 Nov 2026, from Tom's review archive.
 * IMPORTANT: edit-list bypass is ONLY for validating raw byte offsets/sizes.
 * Never use this output as an A/V aligned production timeline.
 * usage: rexx real_mp4_20261105.rex <source.mp4> <unused-reference-csv> <private-out.tsv>
 */
numeric digits 30
parse arg path pk outF
src=.LocalFileSource~new(path)
f=.MediaFile~openMp4(src)
say 'layout' f~layout 'tracks' f~trackCount 'metadata_bytes_read' src~bytesRead
o=.stream~new(outF); o~open('WRITE REPLACE')
do t=1 to f~trackCount
  tr=f~track(t)
  say 'track' t 'id' tr~trackId 'kind' tr~kind 'codec' tr~codecTag 'timescale' tr~timeScale 'duration_ticks' tr~durationTicks 'edits' tr~hasEdits
  if tr~kind<>'soun' then iterate
  b0=src~bytesRead
  m=.MediaMp4SampleTable~new(tr~sampleTable,tr~trackId,tr~timeScale)
  say '  audio samples' m~sampleCount 'index_status' m~indexStatus 'bytes_read_for_sample_table' src~bytesRead-b0
  do i=1 to m~sampleCount
    s=m~sample(i)
    o~lineout(i'09'x||s~presentationTicks'09'x||s~byteOffset'09'x||s~sizeBytes)
  end
end
o~close
say 'total_bytes_read' src~bytesRead 'of' src~sizeBytes
exit 0
::class LocalFileSource subclass MediaByteSource public
::attribute bytesRead get
::method init
  expose s size path bytesRead
  use strict arg path
  s=.stream~new(path); s~open('READ'); size=s~query('size'); bytesRead=0
::method sizeBytes
  expose size; return size
::method sourceIdentity
  expose path size; return path'#'size
::method readAt
  expose s bytesRead
  use strict arg offset,count
  bytesRead+=count
  return s~charin(offset+1,count)
::requires '../src/MediaByteSource.cls'
::requires '../src/Mp4File.cls'
::requires '../src/Mp4SampleTable.cls'
