"""Wholly synthetic Foreign Runtime test provider. No media libraries or images."""
import json


def run_job_file(job_path, result_path, expected_methodology_id=""):
    with open(job_path, "r", encoding="utf-8") as stream:
        job = json.load(stream)
    actual = job["methodology_id"]
    if expected_methodology_id != actual:
        raise ValueError("METHOD_MISMATCH")
    result = {
        "schema": "media-methodology.provider-result/0.1",
        "provider_id": "synthetic.foreign-runtime-smoke/0.1",
        "methodology_id": actual,
        "status": "NOT_APPLICABLE",
        "reason_code": "SYNTHETIC_ONLY_NO_MEDIA",
        "authority": {"effect": "RECONSTRUCT_CANDIDATE", "observation_promotion": False},
    }
    with open(result_path, "w", encoding="utf-8") as stream:
        json.dump(result, stream, sort_keys=True)
    return 0
