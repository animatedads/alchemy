from pathlib import Path
Path("outputs").mkdir(exist_ok=True)
Path("outputs/training-report.json").write_text('{"status":"ok"}\n')
