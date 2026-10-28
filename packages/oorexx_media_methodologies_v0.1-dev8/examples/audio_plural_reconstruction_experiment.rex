#!/usr/bin/env rexx
methods=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(methods)
shapes=.MediaWorkShapeCatalogue~new
.MediaWorkShapeBuiltins~populate(shapes,methods)
ref=.MediaReferenceAudioProviderRegistry~new('providers')
av9=.MediaAudioV9ProviderRegistry~new('providers')
sourceRefs=.array~of('sha256:source-audio#samples=0..79999')
experiment=.MediaExperimentDefinition~new('AUDIO-PLURAL-DEMO','compare plural audio reconstruction methods',sourceRefs)
experiment~addMethod(.MediaExperimentMethodSelection~new('AUDIO.DENOISE.SPECTRAL_SUBTRACTION',ref~profile('AUDIO.DENOISE.SPECTRAL_SUBTRACTION'),'LINEAGE-SPECTRAL-SUB'))
experiment~addMethod(.MediaExperimentMethodSelection~new('AUDIO.DENOISE.WIENER',ref~profile('AUDIO.DENOISE.WIENER'),'LINEAGE-WIENER'))
experiment~addMethod(.MediaExperimentMethodSelection~new('AUDIO.DENOISE.NMF',ref~profile('AUDIO.DENOISE.NMF'),'LINEAGE-NMF'))
experiment~addMethod(.MediaExperimentMethodSelection~new('AUDIO.HARMONIC_PERCUSSIVE',ref~profile('AUDIO.HARMONIC_PERCUSSIVE'),'LINEAGE-HPSS'))
experiment~addMethod(.MediaExperimentMethodSelection~new('AUDIO.RECON.MULTIPATH_VIRTUAL_MIC',av9~profile('AUDIO.RECON.MULTIPATH_VIRTUAL_MIC'),'LINEAGE-MULTIPATH'))
plan=.MediaExperimentPlanner~new~plan(experiment,shapes,1,80000,40000,'SAMPLE')
say 'experiment='experiment~experimentId
say 'lineages='plan~lineageCount
say 'tasks='plan~count
do task over plan~tasks
  say task~lineageId task~workUnit~coreFirst task~workUnit~coreLast task~workUnit~readFirst task~workUnit~readLast
end
exit 0
::requires 'MediaMethodologies.cls'
::requires 'MediaMethodologyBuiltins.cls'
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaWorkShapeBuiltins.cls'
::requires 'MediaMethodologyExperiments.cls'
::requires 'MediaReferenceAudioProviders.cls'
::requires 'MediaAudioV9Providers.cls'
