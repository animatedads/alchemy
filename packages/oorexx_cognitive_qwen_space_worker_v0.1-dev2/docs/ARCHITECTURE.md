# Architecture

```text
Queue Fabric COGNITIVE.LEARNING
        |
        v
CognitiveQwenQueueConsumer
        |
        v
CognitiveQwenSpaceWorker
        |
        v
HFSpaceJobRunner
        |
        v
COGNITIVE_QWEN_INTEGRATION_V1
        |
        v
cognitive.learning.result/2
        |
        v
proposal validation -> ACK
```

A failed or malformed remote result is NACKed. The worker does not possess cognitive admission authority.
