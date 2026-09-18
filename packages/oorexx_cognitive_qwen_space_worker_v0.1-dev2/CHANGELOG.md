# Changelog

## v0.1-dev2

- Add optional result sink to `CognitiveQwenQueueConsumer`.
- A validated Qwen result is captured before Queue Fabric ACK.
- Capture failure NACKs the learning job and returns `LEARNING_RESULT_CAPTURE_FAILED`.
- The sink remains outside Qwen authority; Cognitive Continuity validates and stores results as measurement-only evidence.
- Existing no-sink behaviour remains compatible.
