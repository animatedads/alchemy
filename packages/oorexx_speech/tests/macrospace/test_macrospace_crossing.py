from __future__ import annotations
import sys
import os
import threading
import time
from pathlib import Path

import _rexxpython_poc as bridge

ROOT = Path(__file__).resolve().parents[2]
FACTORY = Path(__file__).with_name('SpeechMacrospaceCrossingFactory.rex')

class SharedTracker:
    def __init__(self):
        self.lock = threading.Lock()
        self.active = 0
        self.peak = 0
        self.completed = 0
    def enter(self):
        with self.lock:
            self.active += 1
            self.peak = max(self.peak, self.active)
    def leave(self):
        with self.lock:
            self.active -= 1
            self.completed += 1

class ProbeProvider:
    def __init__(self, tracker):
        self.tracker = tracker
    def synthesize_to_file(self, text, voice='', language=''):
        self.tracker.enter()
        try:
            time.sleep(0.35)
            return f'probe:{text}'
        finally:
            self.tracker.leave()
    def transcribe_file(self, path, language=''):
        self.tracker.enter()
        try:
            time.sleep(0.35)
            return f'probe-transcript:{path}'
        finally:
            self.tracker.leave()


def main():
    rexx_path = ':'.join([
        str(ROOT / 'src'), str(FACTORY.parent),
        str(Path(sys.argv[1]).resolve()), str(Path(sys.argv[2]).resolve()),
        str(Path(sys.argv[3]).resolve()), str(Path(sys.argv[4]).resolve()),
    ])
    bridge.bootstrap_rexx_package_space(rexx_path, str(ROOT / 'src' / 'SpeechMacrospace.cls'))
    os.environ['OOREXX_SPEECH_PYDIR'] = str(ROOT / 'python')
    factory_answer = bridge.call_program0_text(str(Path(__file__).with_name('test_macrospace_factories.rex')))
    print(factory_answer)
    if factory_answer != 'PASS macrospace local+cloud factories':
        raise SystemExit('factory qualification failed')
    tracker = SharedTracker()
    rexx_handles = []
    python_handles = []
    try:
        for _ in range(4):
            rh, ph = bridge.wrap_python_object(ProbeProvider(tracker), str(FACTORY))
            rexx_handles.append(rh); python_handles.append(ph)
        for peer in rexx_handles[1:]:
            bridge.send1_handle(rexx_handles[0], 'ATTACHLANE', peer)
        answer = bridge.send0_attached(rexx_handles[0], 'RUN')
        print(answer)
        print(f'PYTHON peak={tracker.peak} completed={tracker.completed}')
        if not answer.startswith('PASS '):
            raise SystemExit(1)
        if tracker.completed != 4 or tracker.peak < 4:
            raise SystemExit(f'concurrency failure peak={tracker.peak} completed={tracker.completed}')
    finally:
        for rh in rexx_handles:
            bridge.release_handle(rh)
        for ph in python_handles:
            bridge.release_python_object(ph)

if __name__ == '__main__':
    main()
