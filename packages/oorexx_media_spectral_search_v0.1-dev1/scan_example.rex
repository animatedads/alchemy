/* Example: the caller selects media time and spectral gains in ooRexx. */
parse arg localOgg sourceSha privateDir seekBridge spectrumBridge startMs endMs channel
if channel='' then channel=0
if startMs='' then startMs=100000
if endMs='' then endMs=200000
if localOgg='' | sourceSha='' | privateDir='' | seekBridge='' | spectrumBridge='' then do
  say 'usage: rexx scan_example.rex local_ogg sha256 existing_private_dir seek.bridge.json spectrum.bridge.json [start_ms end_ms channel]'
  exit 2
end
media=.MediaOggFile~new(localOgg,sourceSha,seekBridge,privateDir||'/catalogue.tsv')
search=.MediaSearch~new(spectrumBridge,privateDir)
search~setSpectrum(100,2000,10)
search~setSpectrum(2001,20000,0)
result=search~process(media~seek(startMs,endMs,1,channel))
say 'MAP='||result~path
say 'RECEIPT='||result~receiptPath
say 'MANIFEST='||result~manifestPath
say 'FRAMES='||result~frameCount 'BINS_PER_FRAME='||result~binCount
say 'SOURCE_SHA256='||result~sourceId
exit 0
::requires 'MediaSpectralSearch.cls'
