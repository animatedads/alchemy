from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = (root/'src'/'AudioV9MemoryHorizonExecution.cls').read_text()
test = (root/'tests'/'test_audio_v9_memory_horizon_execution.rex').read_text()
readme = (root/'README.md').read_text()
checks = {
    'api': 'audio.v9.memory-horizon-execution/1' in src,
    'memory_api': 'memory.fabric/0.1' in src,
    'cluster_api': 'cluster.object.peer/0.2' in src,
    'placement_guard': 'PLACEMENT_NOT_VERIFIED' in src,
    'no_pcm_move_assertion': "wire has no resident PCM payload" in test,
    'candidate20': 'candidate20' in readme.lower(),
}
failed = [k for k,v in checks.items() if not v]
if failed:
    raise SystemExit('FAIL package contract: ' + ', '.join(failed))
print('PASS package contract:', ', '.join(checks))
