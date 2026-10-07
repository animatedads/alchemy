from __future__ import annotations
import importlib.util
import pathlib
import sys
import tempfile
import types

ROOT = pathlib.Path(__file__).resolve().parents[1]
MOD = ROOT / "python" / "oorexx_speech_providers.py"

class Signal:
    def __init__(self): self.callbacks=[]
    def connect(self, cb): self.callbacks.append(cb)
    def emit(self, evt):
        for cb in list(self.callbacks): cb(evt)

class FakeResultReason:
    SynthesizingAudioCompleted='tts-ok'
    RecognizedSpeech='recognized'

class FakeFormat:
    Riff24Khz16BitMonoPcm='riff24'

class FakeConfig:
    instances=[]
    def __init__(self, **kw):
        self.kw=kw; self.speech_synthesis_voice_name=''; self.speech_recognition_language=''; self.output_format=None
        type(self).instances.append(self)
    def set_speech_synthesis_output_format(self, fmt): self.output_format=fmt

class FakeAudioOutputConfig:
    def __init__(self, filename): self.filename=filename
class FakeAudioConfig:
    def __init__(self, filename): self.filename=filename

class Async:
    def __init__(self, value=None, fn=None): self.value=value; self.fn=fn
    def get(self):
        if self.fn: self.fn()
        return self.value

class FakeSynth:
    def __init__(self, speech_config, audio_config): self.cfg=speech_config; self.audio=audio_config
    def speak_text_async(self, text):
        pathlib.Path(self.audio.filename).write_bytes(b'RIFFfake')
        return Async(types.SimpleNamespace(reason=FakeResultReason.SynthesizingAudioCompleted))

class FakeRecognizer:
    def __init__(self, speech_config, audio_config):
        self.cfg=speech_config; self.audio=audio_config
        self.recognized=Signal(); self.canceled=Signal(); self.session_stopped=Signal()
    def start_continuous_recognition_async(self):
        def run():
            self.recognized.emit(types.SimpleNamespace(result=types.SimpleNamespace(reason=FakeResultReason.RecognizedSpeech,text='hello')))
            self.recognized.emit(types.SimpleNamespace(result=types.SimpleNamespace(reason=FakeResultReason.RecognizedSpeech,text='azure')))
            self.session_stopped.emit(types.SimpleNamespace())
        return Async(fn=run)
    def stop_continuous_recognition_async(self): return Async()

speech = types.ModuleType('azure.cognitiveservices.speech')
speech.SpeechConfig=FakeConfig
speech.SpeechSynthesisOutputFormat=FakeFormat
speech.ResultReason=FakeResultReason
speech.SpeechSynthesizer=FakeSynth
speech.SpeechRecognizer=FakeRecognizer
speech.SpeechSynthesisCancellationDetails=types.SimpleNamespace(from_result=lambda r: types.SimpleNamespace(error_details=''))
speech.audio=types.SimpleNamespace(AudioOutputConfig=FakeAudioOutputConfig,AudioConfig=FakeAudioConfig)
azure=types.ModuleType('azure'); cognitive=types.ModuleType('azure.cognitiveservices')
sys.modules['azure']=azure; sys.modules['azure.cognitiveservices']=cognitive; sys.modules['azure.cognitiveservices.speech']=speech

spec=importlib.util.spec_from_file_location('oorexx_speech_providers', MOD)
mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

p=mod.AzureSpeechProvider(subscription_key='k', region='uksouth', default_voice='en-GB-SoniaNeural', recognition_timeout_seconds=1)
out=p.synthesize_to_file('hello')
assert pathlib.Path(out).read_bytes()==b'RIFFfake'
assert FakeConfig.instances[-1].kw=={'subscription':'k','region':'uksouth'}
assert FakeConfig.instances[-1].output_format=='riff24'
assert FakeConfig.instances[-1].speech_synthesis_voice_name=='en-GB-SoniaNeural'

with tempfile.NamedTemporaryFile(suffix='.wav') as f:
    text=p.transcribe_file(f.name, 'en-GB')
assert text=='hello azure'
assert FakeConfig.instances[-1].speech_recognition_language=='en-GB'

p2=mod.AzureSpeechProvider(subscription_key='k', endpoint='https://example.invalid/speech')
p2._speech_config()
assert FakeConfig.instances[-1].kw=={'endpoint':'https://example.invalid/speech','subscription':'k'}
print('PASS azure provider mock')
