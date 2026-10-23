"""Resident Python providers intended to be loaded through Python Macrospace.

No subprocesses are launched. Imports are lazy so the same provider module can be
present on systems that install only the backend they use.
"""
from __future__ import annotations

from pathlib import Path
import os
import tempfile
import threading
import queue
import shutil
import uuid


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

    def synthesize_to_file(self, text: str, voice: str = "", language: str = "", profile: str = "") -> str:
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

    def synthesize_to_file(self, text: str, voice: str = "", language: str = "", profile: str = "") -> str:
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
        self._stream_sessions = {}
        self._stream_lock = threading.RLock()
        self._recognition_sessions = {}
        self._recognition_lock = threading.RLock()

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

    @staticmethod
    def _normalized_profile(profile: str) -> str:
        return (profile or "").strip().upper()

    def _tts_output_format(self, speechsdk, profile: str, raw: bool):
        profile = self._normalized_profile(profile)
        if profile == "TELEPHONY-8K":
            return (
                speechsdk.SpeechSynthesisOutputFormat.Raw8Khz16BitMonoPcm
                if raw
                else speechsdk.SpeechSynthesisOutputFormat.Riff8Khz16BitMonoPcm
            )
        if profile == "SPEECH-16K":
            return (
                speechsdk.SpeechSynthesisOutputFormat.Raw16Khz16BitMonoPcm
                if raw
                else speechsdk.SpeechSynthesisOutputFormat.Riff16Khz16BitMonoPcm
            )
        return (
            speechsdk.SpeechSynthesisOutputFormat.Raw24Khz16BitMonoPcm
            if raw
            else speechsdk.SpeechSynthesisOutputFormat.Riff24Khz16BitMonoPcm
        )

    def synthesize_to_file(self, text: str, voice: str = "", language: str = "", profile: str = "") -> str:
        speechsdk = self._sdk()
        config = self._speech_config()
        chosen_voice = voice or self.default_voice
        if chosen_voice:
            config.speech_synthesis_voice_name = chosen_voice
        config.set_speech_synthesis_output_format(
            self._tts_output_format(speechsdk, profile, raw=False)
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

    def begin_synthesis(self, text: str, voice: str = "", language: str = "", profile: str = "") -> str:
        """Begin incremental Azure TTS and return an opaque session id.

        Azure SDK synthesis events are converted into short-lived raw PCM chunk
        files.  This deliberately keeps binary payloads outside Macrospace's
        scalar call surface while preserving true as-available delivery.
        """
        speechsdk = self._sdk()
        config = self._speech_config()
        chosen_voice = voice or self.default_voice
        if chosen_voice:
            config.speech_synthesis_voice_name = chosen_voice
        config.set_speech_synthesis_output_format(
            self._tts_output_format(speechsdk, profile, raw=True)
        )

        session_id = uuid.uuid4().hex
        session_dir = Path(tempfile.mkdtemp(prefix="oorexx-azure-tts-stream-"))
        events = queue.Queue()
        state = {
            "id": session_id,
            "dir": session_dir,
            "events": events,
            "sequence": 0,
            "done": False,
            "cancelled": False,
            "synthesizer": None,
            "future": None,
            "owned_chunks": set(),
        }

        synthesizer = speechsdk.SpeechSynthesizer(speech_config=config, audio_config=None)
        state["synthesizer"] = synthesizer

        def on_synthesizing(evt):
            audio_data = bytes(getattr(evt.result, "audio_data", b"") or b"")
            if not audio_data:
                return
            with self._stream_lock:
                if state["done"] or state["cancelled"]:
                    return
                state["sequence"] += 1
                seq = state["sequence"]
            chunk_path = session_dir / f"chunk-{seq:08d}.pcm"
            chunk_path.write_bytes(audio_data)
            state["owned_chunks"].add(str(chunk_path))
            events.put(("DATA", seq, len(audio_data), str(chunk_path)))

        def on_completed(_evt):
            with self._stream_lock:
                if state["done"]:
                    return
                state["done"] = True
                seq = state["sequence"]
            events.put(("END", seq, 0, ""))

        def on_cancelled(evt):
            details = getattr(evt, "error_details", "") or ""
            reason = getattr(evt, "reason", "") or ""
            with self._stream_lock:
                if state["done"]:
                    return
                state["done"] = True
            events.put(("ERROR", state["sequence"], 0, f"{reason}: {details}".strip(": ")))

        synthesizer.synthesizing.connect(on_synthesizing)
        synthesizer.synthesis_completed.connect(on_completed)
        synthesizer.synthesis_canceled.connect(on_cancelled)

        with self._stream_lock:
            self._stream_sessions[session_id] = state
        try:
            state["future"] = synthesizer.start_speaking_text_async(text)
        except Exception:
            with self._stream_lock:
                self._stream_sessions.pop(session_id, None)
            shutil.rmtree(session_dir, ignore_errors=True)
            raise
        return session_id

    def next_synthesis_chunk(self, session_id: str, timeout_ms: int = 1000) -> str:
        with self._stream_lock:
            state = self._stream_sessions.get(session_id)
        if state is None:
            raise RuntimeError(f"Unknown Azure TTS stream session: {session_id}")
        timeout_seconds = max(0.0, float(timeout_ms) / 1000.0)
        try:
            kind, seq, byte_count, value = state["events"].get(timeout=timeout_seconds)
        except queue.Empty:
            return "WAIT|0|0|"
        if kind == "ERROR":
            self._finish_stream_session(session_id, remove_chunks=False)
            raise RuntimeError(f"Azure Speech streaming TTS failed: {value}")
        if kind == "END":
            with self._stream_lock:
                retired = self._stream_sessions.pop(session_id, None)
            if retired is not None:
                try:
                    retired["dir"].rmdir()
                except OSError:
                    pass
            return f"END|{seq}|0|"
        return f"DATA|{seq}|{byte_count}|{value}"

    def cancel_synthesis(self, session_id: str) -> bool:
        with self._stream_lock:
            state = self._stream_sessions.get(session_id)
        if state is None:
            return False
        state["cancelled"] = True
        synthesizer = state.get("synthesizer")
        try:
            if synthesizer is not None:
                synthesizer.stop_speaking_async().get()
        finally:
            self._finish_stream_session(session_id, remove_chunks=False)
        return True

    def release_synthesis_chunk(self, chunk_ref: str) -> bool:
        if not chunk_ref:
            return False
        path = Path(chunk_ref)
        try:
            path.unlink()
        except FileNotFoundError:
            return False
        with self._stream_lock:
            active_dirs = {str(state["dir"]) for state in self._stream_sessions.values()}
        if str(path.parent) not in active_dirs:
            try:
                path.parent.rmdir()
            except OSError:
                pass
        return True

    def _finish_stream_session(self, session_id: str, remove_chunks: bool = False) -> None:
        with self._stream_lock:
            state = self._stream_sessions.pop(session_id, None)
        if state is None:
            return
        if remove_chunks:
            shutil.rmtree(state["dir"], ignore_errors=True)

    def begin_recognition(
        self,
        language: str = "",
        sample_rate: int = 16000,
        bits_per_sample: int = 16,
        channels: int = 1,
    ) -> str:
        """Begin continuous STT over a caller-fed raw PCM stream.

        The scalar Macrospace boundary carries only session ids and chunk paths.
        Chunk bytes remain external artifacts and are synchronously copied into
        Azure's PushAudioInputStream.
        """
        speechsdk = self._sdk()
        sample_rate = int(sample_rate)
        bits_per_sample = int(bits_per_sample)
        channels = int(channels)
        if bits_per_sample != 16:
            raise ValueError("Azure streaming STT requires 16-bit PCM")
        if channels != 1:
            raise ValueError("Azure streaming STT currently requires mono PCM")
        if sample_rate not in (8000, 16000):
            raise ValueError("Azure streaming STT requires 8000 or 16000 Hz PCM")

        config = self._speech_config()
        if language:
            config.speech_recognition_language = language
        stream_format = speechsdk.audio.AudioStreamFormat(
            samples_per_second=sample_rate,
            bits_per_sample=bits_per_sample,
            channels=channels,
        )
        push_stream = speechsdk.audio.PushAudioInputStream(stream_format=stream_format)
        audio_config = speechsdk.audio.AudioConfig(stream=push_stream)
        recognizer = speechsdk.SpeechRecognizer(speech_config=config, audio_config=audio_config)

        session_id = uuid.uuid4().hex
        events = queue.Queue()
        state = {
            "id": session_id,
            "events": events,
            "sequence": 0,
            "done": False,
            "cancelled": False,
            "input_closed": False,
            "push_stream": push_stream,
            "recognizer": recognizer,
            "language": language,
            "sample_rate": sample_rate,
        }

        def emit_text(kind: str, text: str):
            text = text or ""
            if not text:
                return
            with self._recognition_lock:
                if state["done"] or state["cancelled"]:
                    return
                state["sequence"] += 1
                seq = state["sequence"]
            events.put((kind, seq, text.encode("utf-8").hex()))

        def recognizing(evt):
            result = evt.result
            text = getattr(result, "text", "") or ""
            emit_text("PARTIAL", text)

        def recognized(evt):
            result = evt.result
            if result.reason == speechsdk.ResultReason.RecognizedSpeech:
                emit_text("FINAL", getattr(result, "text", "") or "")

        def canceled(evt):
            details = getattr(evt, "error_details", "") or ""
            reason = getattr(evt, "reason", "") or ""
            with self._recognition_lock:
                if state["done"]:
                    return
                state["done"] = True
                seq = state["sequence"]
            message = f"{reason}: {details}".strip(": ")
            events.put(("ERROR", seq, message.encode("utf-8").hex()))

        def stopped(_evt):
            with self._recognition_lock:
                if state["done"]:
                    return
                state["done"] = True
                seq = state["sequence"]
            events.put(("END", seq, ""))

        recognizer.recognizing.connect(recognizing)
        recognizer.recognized.connect(recognized)
        recognizer.canceled.connect(canceled)
        recognizer.session_stopped.connect(stopped)
        with self._recognition_lock:
            self._recognition_sessions[session_id] = state
        try:
            recognizer.start_continuous_recognition_async().get()
        except Exception:
            with self._recognition_lock:
                self._recognition_sessions.pop(session_id, None)
            try:
                push_stream.close()
            except Exception:
                pass
            raise
        return session_id

    def push_recognition_chunk(self, session_id: str, chunk_ref: str) -> bool:
        with self._recognition_lock:
            state = self._recognition_sessions.get(session_id)
        if state is None:
            raise RuntimeError(f"Unknown Azure STT stream session: {session_id}")
        if state["input_closed"] or state["cancelled"] or state["done"]:
            return False
        data = Path(chunk_ref).read_bytes()
        if len(data) % 2:
            raise ValueError("Azure streaming STT PCM chunk must contain whole 16-bit samples")
        state["push_stream"].write(data)
        return True

    def end_recognition_input(self, session_id: str) -> bool:
        with self._recognition_lock:
            state = self._recognition_sessions.get(session_id)
        if state is None:
            return False
        if state["input_closed"]:
            return True
        state["input_closed"] = True
        state["push_stream"].close()
        return True

    def next_recognition_event(self, session_id: str, timeout_ms: int = 1000) -> str:
        with self._recognition_lock:
            state = self._recognition_sessions.get(session_id)
        if state is None:
            raise RuntimeError(f"Unknown Azure STT stream session: {session_id}")
        timeout_seconds = max(0.0, float(timeout_ms) / 1000.0)
        try:
            kind, seq, text_hex = state["events"].get(timeout=timeout_seconds)
        except queue.Empty:
            return "WAIT|0|"
        if kind == "ERROR":
            self._finish_recognition_session(session_id)
            message = bytes.fromhex(text_hex).decode("utf-8", "replace") if text_hex else ""
            raise RuntimeError(f"Azure Speech streaming STT failed: {message}")
        if kind == "END":
            self._finish_recognition_session(session_id)
            return f"END|{seq}|"
        return f"{kind}|{seq}|{text_hex}"

    def cancel_recognition(self, session_id: str) -> bool:
        with self._recognition_lock:
            state = self._recognition_sessions.get(session_id)
        if state is None:
            return False
        state["cancelled"] = True
        try:
            if not state["input_closed"]:
                state["push_stream"].close()
                state["input_closed"] = True
        finally:
            self._finish_recognition_session(session_id)
        return True

    def _finish_recognition_session(self, session_id: str) -> None:
        with self._recognition_lock:
            state = self._recognition_sessions.pop(session_id, None)
        if state is None:
            return
        recognizer = state.get("recognizer")
        if recognizer is not None:
            try:
                recognizer.stop_continuous_recognition_async().get()
            except Exception:
                pass
        push_stream = state.get("push_stream")
        if push_stream is not None and not state.get("input_closed"):
            try:
                push_stream.close()
            except Exception:
                pass

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
