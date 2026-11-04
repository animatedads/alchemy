import sys
import json
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'src'))
from asr_evidence import normalize
from legacy_recovery import review

JOB={'id':'NATO_A','duration_s':6.0,'source_video_start_s':0.0,'source_audio_start_s':0.0,
     'media_ref':{'sha256':'a'*64},'audio_ref':{'sha256':'b'*64},'pronunciation_hint_unverified':'Alfa'}
GOOGLE={'results':[{'alternatives':[{'words':[{'word':'Well','startOffset':'0.2s','endOffset':'0.6s'},
         {'word':'Alpha','startOffset':'1.0s','endOffset':'1.4s'},
         {'word':'Thanks','startOffset':'2.0s','endOffset':'2.4s'}]}]}]}
AZURE={'source':'https://example.org/NATO_A.wav','recognizedPhrases':[{'recognitionStatus':'Success','nBest':[{'words':[{'word':'Alfa','offsetInTicks':2000000,'durationInTicks':4000000,'confidence':.9}]}]}]}

def do(raw,provider='google',job=JOB): return normalize(job,provider,raw,json.dumps(raw).encode())
class ASREvidence(unittest.TestCase):
    def test_google_review_bridge(self):
        t=do(GOOGLE)
        self.assertEqual(t['source_sha256'],'a'*64)
        r=review(JOB,t)
        self.assertEqual(r['candidate_count'],1)
        self.assertFalse(r['asset_authority_granted'])
        self.assertEqual(r['candidates'][0]['contamination'],'EXTRA_SPEECH_PRESENT')
    def test_azure_review_bridge(self):
        t=do(AZURE,'azure'); self.assertEqual(t['provider'],'azure')
        self.assertEqual(review(JOB,t)['candidate_count'],1)
    def test_google_batch_isolates_clip(self):
        batch={'results':{'gs://bucket/OTHER.wav':{'transcript':{'results':[]}},'gs://bucket/NATO_A.wav':{'transcript':GOOGLE}}}
        self.assertEqual(len(do(batch)['words']),3)
    def test_google_batch_no_single_file_guess(self):
        with self.assertRaisesRegex(ValueError,'AMBIGUOUS_OR_MISSING'):
            do({'results':{'gs://bucket/WRONG.wav':{'transcript':GOOGLE}}})
    def test_google_batch_duplicate_basename(self):
        with self.assertRaisesRegex(ValueError,'AMBIGUOUS_OR_MISSING'):
            do({'results':{'gs://bucket/one/NATO_A.wav':{'transcript':GOOGLE},'gs://bucket/two/NATO_A.wav':{'transcript':GOOGLE}}})
    def test_google_error(self):
        with self.assertRaises(ValueError):do({'error':{'code':403},'results':[]})
    def test_google_missing_offsets(self):
        with self.assertRaises(ValueError):do({'results':[{'alternatives':[{'words':[{'word':'Alpha','endOffset':'2s'}]}]}]})
    def test_azure_string_ticks_refused(self):
        raw=json.loads(json.dumps(AZURE));raw['recognizedPhrases'][0]['nBest'][0]['words'][0]['offsetInTicks']='2000000'
        with self.assertRaises(ValueError):do(raw,'azure')
    def test_azure_wrong_source(self):
        raw=dict(AZURE,source='https://example.org/NATO_B.wav')
        with self.assertRaises(ValueError):do(raw,'azure')
    def test_outside_source_media(self):
        raw={'results':[{'alternatives':[{'words':[{'word':'Alpha','startOffset':'5.9s','endOffset':'6.1s'}]}]}]}
        with self.assertRaises(ValueError):do(raw)
    def test_nan_and_overlap(self):
        raw={'results':[{'alternatives':[{'words':[{'word':'A','startOffset':'NaNs','endOffset':'1s'}]}]}]}
        with self.assertRaises(ValueError):do(raw)
    def test_nonmonotonic(self):
        raw=json.loads(json.dumps(GOOGLE));raw['results'][0]['alternatives'][0]['words'][1]['startOffset']='0.1s'
        with self.assertRaises(ValueError):do(raw)
    def test_no_word_offsets(self):
        with self.assertRaises(ValueError):do({'results':[{'alternatives':[{'transcript':'alpha'}]}]})
    def test_response_sha_and_no_authority(self):
        t=do(GOOGLE);self.assertEqual(len(t['response_sha256']),64)
        self.assertEqual(t['provider_response_authentication'],'NOT_ESTABLISHED_BY_LOCAL_IMPORT')
        self.assertFalse(t['asset_authority_granted'])
    def test_nonzero_audio_offset(self):
        j=dict(JOB,source_audio_start_s=1.0)
        t=do(GOOGLE,job=j);self.assertEqual(t['words'][0]['start_s'],.2)
if __name__=='__main__':unittest.main()
