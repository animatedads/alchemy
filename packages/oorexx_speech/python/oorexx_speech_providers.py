"""Resident Python providers intended to be loaded through Python Macrospace.

No subprocesses are launched. Imports are lazy so the same provider module can be
present on systems that install only the backend they use.
"""
from __future__ import annotations

from pathlib import Path
import os
import tempfile
import threading


class LocalPiperWhisperProvider:
    """Local TTS via piper-tts Python API; STT via faster-whisper.

    Instantiate one object per ooRexx speech channel unless the selected backend
    versions are independently qualified for shared-object concurrent use.
    """

    def __init__(self, piper_model: str = "", whisper_model: str = "small", device: str = "auto"):
        self.piper_model = piper_model or os.environ.get("OOREXX_SPEECH_PIPER_MODEL", "")
        self.whisper_model_name = whisper_model
        self.device = device
        self._piper = None
        self._whisper = None
        self._lock = threading.RLock()

    def _tts(self):
        with self._lock:
            if self._piper is None:
                if not self.piper_model:
                    raise RuntimeError("Piper model path is required")
                from piper.voice import PiperVoice
                self._piper = PiperVoice.load(self.piper_model)
            return self._piper

    def _stt(self):
        with self._lock:
            if self._whisper is None:
                from faster_whisper import WhisperModel
                self._whisper = WhisperModel(self.whisper_model_name, device=self.device)
            return self._whisper

    def synthesize_to_file(self, text: str, voice: str = "", language: str = "") -> str:
        import wave
        fd, path = tempfile.mkstemp(prefix="oorexx-tts-", suffix=".wav")
        os.close(fd)
        with wave.open(path, "wb") as wav_file:
            self._tts().synthesize_wav(text, wav_file)
        return path

    def transcribe_file(self, path: str, language: str = "") -> str:
        kwargs = {}
        if language:
            kwargs["language"] = language
        segments, _info = self._stt().transcribe(path, **kwargs)
        return "".join(segment.text for segment in segments).strip()


class OpenAICloudSpeechProvider:
    """Cloud provider using the OpenAI Python SDK audio surfaces.

    Model names are caller configuration, not package constants, so cloud model
    evolution does not alter the ooRexx speech contract.
    """

    def __init__(self, tts_model: str, stt_model: str, default_voice: str = ""):
        self.tts_model = tts_model
        self.stt_model = stt_model
        self.default_voice = default_voice
        self._openai_client = None
        self._lock = threading.RLock()

    def _client(self):
        with self._lock:
            if self._openai_client is None:
                from openai import OpenAI
                self._openai_client = OpenAI()
            return self._openai_client

    def synthesize_to_file(self, text: str, voice: str = "", language: str = "") -> str:
        chosen_voice = voice or self.default_voice
        if not chosen_voice:
            raise RuntimeError("Cloud TTS voice is required")
        fd, path = tempfile.mkstemp(prefix="oorexx-cloud-tts-", suffix=".wav")
        os.close(fd)
        response = self._client().audio.speech.create(
            model=self.tts_model,
            voice=chosen_voice,
            input=text,
            response_format="wav",
        )
        if hasattr(response, "stream_to_file"):
            response.stream_to_file(path)
        elif hasattr(response, "write_to_file"):
            response.write_to_file(path)
        else:
            Path(path).write_bytes(response.read())
        return path

    def transcribe_file(self, path: str, language: str = "") -> str:
        kwargs = {"model": self.stt_model}
        if language:
            kwargs["language"] = language
        with open(path, "rb") as audio_file:
            result = self._client().audio.transcriptions.create(file=audio_file, **kwargs)
        return getattr(result, "text", str(result))

class AzureSpeechProvider:
    """Azure AI Speech provider for batch/file TTS and STT.

    The Azure Speech SDK remains behind Python Macrospace.  One provider object
    should normally be resident per ooRexx speech channel, matching the package's
    existing concurrency contract.

    Configuration precedence:
      constructor -> OOREXX_SPEECH_AZURE_* -> Microsoft's SPEECH_*/ENDPOINT names.
    """

    def __init__(
        self,
        subscription_key: str = "",
        region: str = "",
        endpoint: str = "",
        default_voice: str = "",
        recognition_timeout_seconds: float = 3600.0,
    ):
        self.subscription_key = (
            subscription_key
            or os.environ.get("OOREXX_SPEECH_AZURE_KEY", "")
            or os.environ.get("SPEECH_KEY", "")
        )
        self.region = (
            region
            or os.environ.get("OOREXX_SPEECH_AZURE_REGION", "")
            or os.environ.get("SPEECH_REGION", "")
        )
        self.endpoint = (
            endpoint
            or os.environ.get("OOREXX_SPEECH_AZURE_ENDPOINT", "")
            or os.environ.get("ENDPOINT", "")
        )
        self.default_voice = default_voice or os.environ.get("OOREXX_SPEECH_AZURE_VOICE", "")
        self.recognition_timeout_seconds = float(recognition_timeout_seconds)
        self._speechsdk = None
        self._lock = threading.RLock()

    def _sdk(self):
        with self._lock:
            if self._speechsdk is None:
                import azure.cognitiveservices.speech as speechsdk
                self._speechsdk = speechsdk
            return self._speechsdk

    def _speech_config(self):
        if not self.subscription_key:
            raise RuntimeError("Azure Speech subscription key is required")
        speechsdk = self._sdk()
        if self.endpoint:
            return speechsdk.SpeechConfig(endpoint=self.endpoint, subscription=self.subscription_key)
        if not self.region:
            raise RuntimeError("Azure Speech region is required when endpoint is not supplied")
        return speechsdk.SpeechConfig(subscription=self.subscription_key, region=self.region)

    def synthesize_to_file(self, text: str, voice: str = "", language: str = "") -> str:
        speechsdk = self._sdk()
        config = self._speech_config()
        chosen_voice = voice or self.default_voice
        if chosen_voice:
            config.speech_synthesis_voice_name = chosen_voice
        config.set_speech_synthesis_output_format(
            speechsdk.SpeechSynthesisOutputFormat.Riff24Khz16BitMonoPcm
        )
        fd, path = tempfile.mkstemp(prefix="oorexx-azure-tts-", suffix=".wav")
        os.close(fd)
        try:
            audio = speechsdk.audio.AudioOutputConfig(filename=path)
            synthesizer = speechsdk.SpeechSynthesizer(speech_config=config, audio_config=audio)
            completed = synthesizer.speak_text_async(text).get()
            if completed.reason != speechsdk.ResultReason.SynthesizingAudioCompleted:
                details = speechsdk.SpeechSynthesisCancellationDetails.from_result(completed)
                detail_text = getattr(details, "error_details", "") or str(details)
                raise RuntimeError(f"Azure Speech TTS failed: {detail_text}")
            return path
        except Exception:
            try:
                os.unlink(path)
            except FileNotFoundError:
                pass
            raise

    def transcribe_file(self, path: str, language: str = "") -> str:
        speechsdk = self._sdk()
        config = self._speech_config()
        if language:
            config.speech_recognition_language = language
        audio = speechsdk.audio.AudioConfig(filename=path)
        recognizer = speechsdk.SpeechRecognizer(speech_config=config, audio_config=audio)
        finished = threading.Event()
        phrases = []
        cancellation = []

        def recognized(evt):
            result = evt.result
            if result.reason == speechsdk.ResultReason.RecognizedSpeech and result.text:
                phrases.append(result.text)

        def canceled(evt):
            cancellation.append(evt)
            finished.set()

        def stopped(_evt):
            finished.set()

        recognizer.recognized.connect(recognized)
        recognizer.canceled.connect(canceled)
        recognizer.session_stopped.connect(stopped)
        recognizer.start_continuous_recognition_async().get()
        try:
            if not finished.wait(self.recognition_timeout_seconds):
                raise TimeoutError("Azure Speech STT timed out")
        finally:
            recognizer.stop_continuous_recognition_async().get()

        if cancellation:
            evt = cancellation[-1]
            details = getattr(evt, "error_details", "")
            reason = getattr(evt, "reason", "")
            if details:
                raise RuntimeError(f"Azure Speech STT canceled: {reason}: {details}")
        return " ".join(part.strip() for part in phrases if part.strip()).strip()

