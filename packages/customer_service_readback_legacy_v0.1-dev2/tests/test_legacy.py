import copy
import json
import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'src'))
from legacy_recovery import plan, review

class Recovery(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        alpha='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        ids=['LETTER_'+s for s in alpha]+['NATO_'+s for s in alpha]+['NUM_'+str(i).zfill(7) for i in range(31)]
        sample=[]
        for name in ids:
            sample.append({'id':name,'member':'A02/'+name+'.mp4','source_sha256':'a'*64,
                'prepared_audio_sha256':'b'*64,'prepared_audio':'audio/'+name+'.wav',
                'video':{'start_time':'0','duration':'6'},'audio':{'start_time':'0'}})
        cls.prepared={'schema':'customer.agent.batch.prepare/0.1','complete':True,'processed':len(sample),'clips':sample}
        cls.vocabulary=json.loads((ROOT/'examples/readback_vocabulary.json').read_text())
        cls.work=plan(cls.prepared,cls.vocabulary)
        cls.job=next(j for j in cls.work['jobs'] if j['id']=='NATO_A')
    def transcript(self, words=('Well','Alpha','Thanks')):
        return {'schema':'customer.agent.transcript.words/0.1','status':'RECOGNIZED_UNVERIFIED',
            'timestamp_origin':'extracted_audio_start','clip':self.job['id']+'.mp4',
            'source_sha256':self.job['media_ref']['sha256'],'audio_sha256':self.job['audio_ref']['sha256'],
            'words':[{'word':w,'start_s':i*.5,'end_s':i*.5+.3} for i,w in enumerate(words)]}
    def test_83_deterministic(self):
        self.assertEqual(self.work['candidate_jobs'],83)
        self.assertEqual(len({x['id'] for x in self.work['jobs']}),83)
        self.assertEqual(plan(self.prepared,self.vocabulary),self.work)
    def test_no_authority(self):
        self.assertTrue(all(not x['promotion_authorized'] for x in self.work['jobs']))
    def test_salvage_extra_speech(self):
        r=review(self.job,self.transcript())
        self.assertEqual(r['decision'],'CANDIDATES_REQUIRE_REVIEW')
        self.assertEqual(r['candidate_count'],1)
        self.assertEqual(r['candidates'][0]['contamination'],'EXTRA_SPEECH_PRESENT')
        self.assertFalse(r['asset_authority_granted'])
    def test_wrong_source(self):
        t=self.transcript();t['source_sha256']='bad'
        self.assertEqual(review(self.job,t)['decision'],'REJECT_EVIDENCE')
    def test_wrong_audio(self):
        t=self.transcript();t['audio_sha256']='bad'
        self.assertEqual(review(self.job,t)['decision'],'REJECT_EVIDENCE')
    def test_bad_time(self):
        t=self.transcript();t['words'][1]['end_s']=-1
        self.assertEqual(review(self.job,t)['decision'],'REJECT_EVIDENCE')
    def test_nonzero_start_offset(self):
        job=dict(self.job,source_audio_start_s=1.5,source_video_start_s=.5)
        self.assertEqual(review(job,self.transcript())['candidates'][0]['video_interval_s'][0],1.4)
    def test_unmatched(self):
        self.assertEqual(review(self.job,self.transcript(('silly','cats')))['decision'],'NO_MATCH_REGENERATE_OR_REVIEW')
    def test_no_words(self):
        self.assertEqual(review(self.job,self.transcript(()))['decision'],'REJECT_EVIDENCE')
    def test_malformed_prepared(self):
        with self.assertRaises(ValueError):plan({'schema':'wrong'}, {})
    def test_missing_pin(self):
        prepared=copy.deepcopy(self.prepared)
        next(x for x in prepared['clips'] if x['id']=='NATO_A')['source_sha256']=''
        with self.assertRaises(ValueError):plan(prepared,self.vocabulary)

if __name__=='__main__':unittest.main()
